import AppKit
import Combine
import Foundation

@MainActor
final class SoniqoController: ObservableObject {
    @Published private(set) var outputDevices: [AudioOutputDevice] = []
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var defaultOutputDevice: AudioOutputDevice?
    @Published private(set) var trackedWindow: TrackedWindow?
    @Published private(set) var trackedDisplay: DisplayInfo?
    @Published private(set) var playbackWindows: [TrackedWindow] = []
    @Published private(set) var audibleProcesses: [AudioProcess] = []
    @Published private(set) var statusMessage = "Automatic switching is off."
    @Published var preferences: RoutingPreferences {
        didSet {
            savePreferences()
            updateTimer()
        }
    }

    private let audioOutputService = AudioOutputService()
    private let audioProcessService = AudioProcessService()
    private let displayService = DisplayService()
    private let windowTrackingService = WindowTrackingService()
    private var timerCancellable: AnyCancellable?
    private var lastAudibleProcessIDs = Set<pid_t>()

    private let preferencesKey = "routingPreferences"

    init() {
        preferences = Self.loadPreferences(key: preferencesKey)
        refreshInventory()
        updateTimer()
    }

    deinit {
        timerCancellable?.cancel()
    }

    var isEnabled: Bool {
        preferences.isEnabled
    }

    func setEnabled(_ isEnabled: Bool) {
        preferences.isEnabled = isEnabled
        statusMessage = isEnabled ? "Automatic switching is on." : "Automatic switching is off."

        if isEnabled {
            evaluateAndRoute()
        }
    }

    func refreshInventory() {
        displays = displayService.displays()

        do {
            outputDevices = try audioOutputService.outputDevices()
            defaultOutputDevice = try audioOutputService.defaultOutputDevice()
            autoConfigureMissingPreferences()
            reconcilePreferencesWithConnectedDevices()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func setMappedDevice(uid: String?, for display: DisplayInfo) {
        if let uid {
            preferences.screenDeviceUIDs[display.storageKey] = uid
        } else {
            preferences.screenDeviceUIDs.removeValue(forKey: display.storageKey)
        }
    }

    func mappedDeviceUID(for display: DisplayInfo) -> String? {
        preferences.screenDeviceUIDs[display.storageKey]
    }

    func routeNow() {
        refreshInventory()
        evaluateAndRoute()
    }

    func autoConfigure() {
        refreshInventory()
        autoConfigureMissingPreferences(overwriteExistingMappings: true)
        statusMessage = "Screen routing was auto-configured from connected devices."

        if preferences.isEnabled {
            evaluateAndRoute()
        }
    }

    private func updateTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil

        guard preferences.isEnabled else {
            return
        }

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateAndRoute()
            }
    }

    private func evaluateAndRoute() {
        guard preferences.isEnabled else {
            return
        }

        do {
            audibleProcesses = try audioProcessService.runningOutputProcesses()
        } catch {
            audibleProcesses = []
            statusMessage = error.localizedDescription
        }

        let audibleProcessIDs = Set(audibleProcesses.map(\.id))
        let hasNewAudibleProcess = !audibleProcessIDs.subtracting(lastAudibleProcessIDs).isEmpty
        lastAudibleProcessIDs = audibleProcessIDs

        playbackWindows = windowTrackingService.playbackWindows(audibleProcesses: audibleProcesses)
        trackedWindow = selectedPrimaryPlaybackWindow(hasNewAudibleProcess: hasNewAudibleProcess)

        guard let window = trackedWindow else {
            trackedDisplay = nil
            statusMessage = audibleProcesses.isEmpty
                ? "No process is currently producing audio output."
                : "Audio output is active, but no matching visible window was found."
            return
        }

        if displays.isEmpty {
            displays = displayService.displays()
        }

        guard let display = displayService.display(containingLargestAreaOf: window.frame, in: displays) else {
            trackedDisplay = nil
            statusMessage = "No screen matched \(window.ownerName)."
            return
        }

        trackedDisplay = display

        if let mappedUID = preferences.screenDeviceUIDs[display.storageKey] {
            route(to: mappedUID, reason: "\(window.ownerName) is on \(display.name).")
        } else {
            statusMessage = "\(display.name) has no mapped output."
        }
    }

    private func route(to uid: String, reason: String) {
        do {
            let currentDefault = try audioOutputService.defaultOutputDevice()
            defaultOutputDevice = currentDefault

            guard currentDefault?.uid != uid else {
                let name = currentDefault?.displayName ?? "selected output"
                statusMessage = "\(reason) Already using \(name)."
                return
            }

            try audioOutputService.setDefaultOutputDevice(uid: uid)
            defaultOutputDevice = try audioOutputService.defaultOutputDevice()
            let outputName = defaultOutputDevice?.displayName ?? "selected output"
            statusMessage = "\(reason) Routed to \(outputName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func reconcilePreferencesWithConnectedDevices() {
        let connectedUIDs = Set(outputDevices.map(\.uid))

        preferences.screenDeviceUIDs = preferences.screenDeviceUIDs.filter { _, uid in
            connectedUIDs.contains(uid)
        }
    }

    private func autoConfigureMissingPreferences(overwriteExistingMappings: Bool = false) {
        for display in displays {
            if !overwriteExistingMappings, preferences.screenDeviceUIDs[display.storageKey] != nil {
                continue
            }

            if let matchedDevice = bestOutputMatch(for: display) {
                preferences.screenDeviceUIDs[display.storageKey] = matchedDevice.uid
            }
        }
    }

    private func bestOutputMatch(for display: DisplayInfo) -> AudioOutputDevice? {
        let displayName = normalizedName(display.name)

        if let exactMatch = outputDevices.first(where: { normalizedName($0.displayName) == displayName }) {
            return exactMatch
        }

        return outputDevices.first { device in
            let deviceName = normalizedName(device.displayName)
            return displayName.contains(deviceName) || deviceName.contains(displayName)
        }
    }

    private func normalizedName(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private func selectedPrimaryPlaybackWindow(hasNewAudibleProcess: Bool) -> TrackedWindow? {
        guard !playbackWindows.isEmpty else {
            return nil
        }

        if let foregroundWindow = windowTrackingService.foregroundWindow(),
           windowTrackingService.window(foregroundWindow, matches: audibleProcesses),
           let currentForegroundWindow = playbackWindows.first(where: { $0.windowID == foregroundWindow.windowID }) {
            return currentForegroundWindow
        }

        if !hasNewAudibleProcess,
           let trackedWindow,
           let currentTrackedWindow = playbackWindows.first(where: { $0.windowID == trackedWindow.windowID }) {
            return currentTrackedWindow
        }

        if playbackWindows.count == 1 {
            return playbackWindows[0]
        }

        if let trackedWindow,
           let currentTrackedWindow = playbackWindows.first(where: { $0.windowID == trackedWindow.windowID }) {
            return currentTrackedWindow
        }

        return nil
    }

    private func savePreferences() {
        guard let data = try? JSONEncoder().encode(PreferencesPayload(preferences)) else {
            return
        }

        UserDefaults.standard.set(data, forKey: preferencesKey)
    }

    private static func loadPreferences(key: String) -> RoutingPreferences {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let payload = try? JSONDecoder().decode(PreferencesPayload.self, from: data)
        else {
            return .defaults
        }

        return payload.preferences
    }
}

private struct PreferencesPayload: Codable {
    let isEnabled: Bool
    let screenDeviceUIDs: [String: String]

    init(_ preferences: RoutingPreferences) {
        isEnabled = preferences.isEnabled
        screenDeviceUIDs = preferences.screenDeviceUIDs
    }

    var preferences: RoutingPreferences {
        RoutingPreferences(
            isEnabled: isEnabled,
            screenDeviceUIDs: screenDeviceUIDs
        )
    }
}
