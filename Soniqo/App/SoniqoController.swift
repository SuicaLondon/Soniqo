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
    @Published private(set) var inventoryErrorMessage: String?
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
    private var screenParametersCancellable: AnyCancellable?
    private var volumeReadbackWorkItem: DispatchWorkItem?
    private var lastAudibleProcessIDs = Set<pid_t>()

    private let preferencesKey = "routingPreferences"

    init() {
        preferences = Self.loadPreferences(key: preferencesKey)
        refreshInventory()
        observeScreenChanges()
        updateTimer()
    }

    deinit {
        timerCancellable?.cancel()
        screenParametersCancellable?.cancel()
        volumeReadbackWorkItem?.cancel()
    }

    var isEnabled: Bool {
        preferences.isEnabled
    }

    var monitorAudioStatuses: [MonitorAudioStatus] {
        displays.map { display in
            let mappedUID = mappedDeviceUID(for: display)
            let mappedDevice = outputDevices.first { $0.uid == mappedUID }

            return MonitorAudioStatus(
                display: display,
                mappedDeviceUID: mappedUID,
                outputDevice: mappedDevice,
                inventoryIsAvailable: inventoryErrorMessage == nil
            )
        }
    }

    var routableOutputDevices: [AudioOutputDevice] {
        outputDevices.filter(\.isRoutable)
    }

    var hasUnknownOutputDevices: Bool {
        outputDevices.contains { $0.routingAvailability == .unknown }
    }

    func setEnabled(_ isEnabled: Bool) {
        preferences.isEnabled = isEnabled
        statusMessage = isEnabled ? "Automatic switching is on." : "Automatic switching is off."

        if isEnabled, refreshInventory() {
            evaluateAndRoute()
        }
    }

    @discardableResult
    func refreshInventory() -> Bool {
        let refreshedDisplays = displayService.displays()
        if displays != refreshedDisplays {
            displays = refreshedDisplays
        }

        let refreshedDevices: [AudioOutputDevice]
        do {
            refreshedDevices = try audioOutputService.outputDevices()
        } catch {
            outputDevices = []
            defaultOutputDevice = nil
            inventoryErrorMessage = error.localizedDescription
            return false
        }

        if outputDevices != refreshedDevices {
            outputDevices = refreshedDevices
        }
        autoConfigureMissingPreferences()

        do {
            let refreshedDefault = try audioOutputService.defaultOutputDevice(in: refreshedDevices)
            if defaultOutputDevice != refreshedDefault {
                defaultOutputDevice = refreshedDefault
            }
        } catch {
            defaultOutputDevice = nil
            inventoryErrorMessage = error.localizedDescription
            return false
        }

        inventoryErrorMessage = nil
        return true
    }

    func setMappedDevice(uid: String?, for display: DisplayInfo) {
        guard mappedDeviceUID(for: display) != uid else {
            return
        }

        var mappings = preferences.screenDeviceUIDs
        mappings.removeValue(forKey: display.legacyStorageKey)
        if let uid {
            mappings[display.storageKey] = uid
        } else {
            mappings.removeValue(forKey: display.storageKey)
        }
        preferences.screenDeviceUIDs = mappings

        if preferences.isEnabled, trackedDisplay?.id == display.id {
            evaluateAndRoute()
        }
    }

    func mappedDeviceUID(for display: DisplayInfo) -> String? {
        preferences.screenDeviceUIDs[display.storageKey]
            ?? preferences.screenDeviceUIDs[display.legacyStorageKey]
    }

    func selectMonitorForPlayback(_ display: DisplayInfo) {
        guard !preferences.isEnabled else {
            statusMessage = "Turn off Auto to switch outputs manually."
            return
        }

        guard let mappedUID = mappedDeviceUID(for: display) else {
            statusMessage = "Choose an audio output for \(display.name) first."
            return
        }

        guard let device = outputDevices.first(where: { $0.uid == mappedUID }) else {
            statusMessage = "The audio output mapped to \(display.name) is disconnected."
            return
        }

        guard device.isRoutable else {
            statusMessage = "\(device.displayName) cannot be selected right now."
            return
        }

        route(to: mappedUID, reason: "Manual switch to \(display.name).")
    }

    func setVolume(_ level: Float, forDeviceUID uid: String) {
        guard let device = outputDevices.first(where: { $0.uid == uid }) else {
            statusMessage = "The selected audio output is no longer available."
            return
        }

        do {
            try audioOutputService.setVolume(level, for: device)
            let normalizedLevel = min(max(level, 0), 1)
            let updatedDevice = device.replacingVolumeState(
                .level(normalizedLevel, muteState: device.volumeState.muteState)
            )
            outputDevices = outputDevices.map { candidate in
                candidate.uid == uid ? updatedDevice : candidate
            }

            if defaultOutputDevice?.uid == uid {
                defaultOutputDevice = updatedDevice
            }
            scheduleVolumeReadback()
        } catch {
            statusMessage = error.localizedDescription
            _ = refreshInventory()
        }
    }

    func routeNow() {
        if refreshInventory() {
            evaluateAndRoute()
        }
    }

    func autoConfigure() {
        guard refreshInventory() else {
            return
        }

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
                guard let self, self.refreshInventory() else {
                    return
                }

                self.evaluateAndRoute()
            }
    }

    private func scheduleVolumeReadback() {
        volumeReadbackWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.volumeReadbackWorkItem = nil
            self?.refreshInventory()
        }
        volumeReadbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func observeScreenChanges() {
        screenParametersCancellable = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshInventory()
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

        if let mappedUID = mappedDeviceUID(for: display) {
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
            defaultOutputDevice = outputDevices.first { $0.uid == uid }
            let outputName = defaultOutputDevice?.displayName ?? "selected output"
            statusMessage = "\(reason) Routed to \(outputName)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func autoConfigureMissingPreferences(overwriteExistingMappings: Bool = false) {
        var mappings = preferences.screenDeviceUIDs
        var availableDeviceUIDs = Set(outputDevices.filter(\.isRoutable).map(\.uid))

        for display in displays where mappings[display.storageKey] == nil {
            if let legacyUID = mappings.removeValue(forKey: display.legacyStorageKey) {
                mappings[display.storageKey] = legacyUID
            }
        }

        if !overwriteExistingMappings {
            for display in displays {
                if let mappedUID = mappings[display.storageKey] {
                    availableDeviceUIDs.remove(mappedUID)
                }
            }
        }

        for display in displays {
            if !overwriteExistingMappings, mappings[display.storageKey] != nil {
                continue
            }

            let candidates = outputDevices.filter { availableDeviceUIDs.contains($0.uid) }
            if let matchedDevice = bestOutputMatch(for: display, candidates: candidates) {
                mappings[display.storageKey] = matchedDevice.uid
                availableDeviceUIDs.remove(matchedDevice.uid)
            }
        }

        if mappings != preferences.screenDeviceUIDs {
            preferences.screenDeviceUIDs = mappings
        }
    }

    private func bestOutputMatch(
        for display: DisplayInfo,
        candidates: [AudioOutputDevice]
    ) -> AudioOutputDevice? {
        let routableDevices = candidates.filter(\.isRoutable)
        let displayName = normalizedName(display.name)

        let exactMatches = routableDevices.filter { normalizedName($0.displayName) == displayName }
        if exactMatches.count == 1 {
            return exactMatches[0]
        }

        if display.isBuiltIn,
           let builtInOutput = routableDevices.first(where: \.isBuiltIn) {
            return builtInOutput
        }

        let partialMatches = routableDevices.filter { device in
            let deviceName = normalizedName(device.displayName)
            return displayName.contains(deviceName) || deviceName.contains(displayName)
        }
        if partialMatches.count == 1 {
            return partialMatches[0]
        }

        if displays.count == 1, candidates.count == 1 {
            return routableDevices[0]
        }

        return nil
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
