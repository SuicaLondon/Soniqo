import AppKit
import Combine
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: SoniqoController
    @StateObject private var layoutState = MenuBarLayoutState()

    private let refreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var scrollViewportHeight: CGFloat {
        min(layoutState.contentHeight, layoutState.maximumHeight)
    }

    private var contentNeedsScrolling: Bool {
        layoutState.contentHeight > layoutState.maximumHeight + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .opacity(0.55)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    currentOutputSection
                    monitorsSection
                    statusBanner
                }
                .padding(16)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ScrollContentHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                }
            }
            .scrollDisabled(!contentNeedsScrolling)
            .scrollIndicators(contentNeedsScrolling ? .automatic : .hidden)
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: scrollViewportHeight)
            .onPreferenceChange(ScrollContentHeightPreferenceKey.self) { height in
                guard height > 0 else {
                    return
                }

                let measuredHeight = ceil(height)
                if abs(layoutState.contentHeight - measuredHeight) > 0.5 {
                    layoutState.contentHeight = measuredHeight
                }
            }

            Divider()
                .opacity(0.55)

            footer
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            updateMaximumScrollHeight()
            DispatchQueue.main.async {
                updateMaximumScrollHeight()
            }
            controller.refreshInventory()
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )) { _ in
            updateMaximumScrollHeight()
        }
        .onReceive(refreshTimer) { _ in
            if !controller.isEnabled {
                controller.refreshInventory()
            }
        }
    }

    private func updateMaximumScrollHeight() {
        let pointerLocation = NSEvent.mouseLocation
        let targetScreen = NSApplication.shared.keyWindow?.screen ?? NSScreen.screens.first { screen in
            screen.frame.contains(pointerLocation)
        } ?? NSScreen.main ?? NSScreen.screens.first

        // Header, footer, dividers, popover arrow, and a small screen-edge margin.
        let nonScrollingHeight: CGFloat = 140
        let visibleScreenHeight = targetScreen?.visibleFrame.height ?? 700
        layoutState.maximumHeight = max(160, visibleScreenHeight - nonScrollingHeight)
    }

    private var header: some View {
        HStack(spacing: 11) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Soniqo")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Text("Audio follows the active screen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 7) {
                Text("Auto")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(controller.isEnabled ? Color.primary : Color.secondary)

                Toggle("Automatic audio routing", isOn: Binding(
                    get: { controller.isEnabled },
                    set: { controller.setEnabled($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .accessibilityLabel("Automatic audio routing")
                .accessibilityValue(controller.isEnabled ? "On" : "Off")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var currentOutputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(title: "CURRENT OUTPUT")

            CurrentOutputCard(
                device: controller.defaultOutputDevice,
                isEnabled: controller.isEnabled,
                trackedWindow: controller.trackedWindow,
                trackedDisplay: controller.trackedDisplay,
                inventoryErrorMessage: controller.inventoryErrorMessage
            )
        }
    }

    private var monitorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeading(
                title: "MONITORS",
                detail: "\(controller.displays.count) CONNECTED"
            )

            if controller.monitorAudioStatuses.isEmpty {
                EmptyMonitorCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(controller.monitorAudioStatuses) { status in
                        MonitorCard(
                            status: status,
                            availableDevices: controller.routableOutputDevices,
                            hasUnknownDevices: controller.hasUnknownOutputDevices,
                            currentOutputUID: controller.defaultOutputDevice?.uid,
                            isTracked: controller.trackedDisplay?.id == status.display.id,
                            autoRoutingEnabled: controller.isEnabled,
                            onSelectDevice: { uid in
                                controller.setMappedDevice(uid: uid, for: status.display)
                            },
                            onSwitchOutput: {
                                controller.selectMonitorForPlayback(status.display)
                            },
                            onSetVolume: { level in
                                guard let deviceUID = status.outputDevice?.uid else {
                                    return
                                }

                                controller.setVolume(level, forDeviceUID: deviceUID)
                            }
                        )
                    }
                }
            }
        }
    }

    private var statusBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: statusSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 16, height: 16)

            Text(displayedStatusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(statusColor.opacity(0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(statusColor.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                controller.refreshInventory()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(FooterButtonStyle())
            .keyboardShortcut("r", modifiers: .command)
            .help("Refresh monitors and audio outputs")

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit Soniqo", systemImage: "power")
            }
            .buttonStyle(FooterButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusHasError: Bool {
        guard controller.inventoryErrorMessage == nil else {
            return true
        }

        let message = displayedStatusMessage.lowercased()
        return message.contains("failed")
            || message.contains("no longer available")
            || message.contains("cannot be used")
    }

    private var displayedStatusMessage: String {
        controller.inventoryErrorMessage ?? controller.statusMessage
    }

    private var statusSymbol: String {
        if statusHasError {
            return "exclamationmark.triangle.fill"
        }

        return controller.isEnabled ? "waveform" : "pause.fill"
    }

    private var statusColor: Color {
        if statusHasError {
            return .orange
        }

        return controller.isEnabled ? .accentColor : .secondary
    }
}

private struct CurrentOutputCard: View {
    let device: AudioOutputDevice?
    let isEnabled: Bool
    let trackedWindow: TrackedWindow?
    let trackedDisplay: DisplayInfo?
    let inventoryErrorMessage: String?

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))

                Image(systemName: deviceSymbol)
                    .font(.system(size: 19, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(device == nil ? Color.orange : Color.accentColor)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(currentOutputTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(currentOutputTitle)

                Label(routeDescription, systemImage: routeSymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if inventoryErrorMessage != nil || device?.routingAvailability == .unknown {
                Text("UNKNOWN")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            } else if device?.routingAvailability == .unavailable {
                Text("UNAVAILABLE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            } else if let device {
                CurrentVolumeReadout(volumeState: device.volumeState)
            } else {
                Text("UNAVAILABLE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.11),
                            Color.purple.opacity(0.045),
                            Color.primary.opacity(0.025)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.20), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var deviceSymbol: String {
        if inventoryErrorMessage != nil {
            return "questionmark.circle.fill"
        }

        guard let device else {
            return "speaker.slash.fill"
        }

        if device.routingAvailability == .unknown {
            return "questionmark.circle.fill"
        }

        if device.routingAvailability == .unavailable {
            return "speaker.slash.fill"
        }

        return speakerSymbol(for: device.volumeState)
    }

    private var currentOutputTitle: String {
        if inventoryErrorMessage != nil {
            return "Current output unknown"
        }

        return device?.displayName ?? "No audio output"
    }

    private var routeDescription: String {
        if inventoryErrorMessage != nil {
            return "Audio device inventory could not be read"
        }

        if device?.routingAvailability == .unknown {
            return "Output availability could not be verified"
        }

        if device?.routingAvailability == .unavailable {
            return "This output is not available right now"
        }

        if !isEnabled {
            return "Automatic routing is paused"
        }

        if let trackedWindow, let trackedDisplay {
            return "\(trackedWindow.ownerName)  →  \(trackedDisplay.name)"
        }

        return "Waiting for an audible window"
    }

    private var routeSymbol: String {
        if !isEnabled {
            return "pause.circle"
        }

        return trackedDisplay == nil ? "waveform" : "rectangle.on.rectangle"
    }
}

private struct CurrentVolumeReadout: View {
    let volumeState: AudioVolumeState

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if volumeState.isMuted {
                Text("MUTED")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)

                if let percentage = volumeState.percentage {
                    Text("\(percentage)% set")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else if let percentage = volumeState.percentage {
                Text("\(percentage)%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text("VOLUME")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else if volumeState.isDeviceControlled {
                Text("DEVICE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))

                Text("CONTROLLED")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text("UNKNOWN")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)

                Text("VOLUME")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        if volumeState.isMuted {
            return "Muted"
        }

        if let percentage = volumeState.percentage {
            return "Volume \(percentage) percent"
        }

        if volumeState.isDeviceControlled {
            return "Volume is controlled by the audio device"
        }

        return "Volume could not be read"
    }
}

private struct MonitorCard: View {
    let status: MonitorAudioStatus
    let availableDevices: [AudioOutputDevice]
    let hasUnknownDevices: Bool
    let currentOutputUID: String?
    let isTracked: Bool
    let autoRoutingEnabled: Bool
    let onSelectDevice: (String) -> Void
    let onSwitchOutput: () -> Void
    let onSetVolume: (Float) -> Void

    private var device: AudioOutputDevice? {
        status.outputDevice
    }

    private var isCurrentSystemOutput: Bool {
        guard let device else {
            return false
        }

        return device.uid == currentOutputUID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isTracked ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.055))

                    Image(systemName: status.display.isBuiltIn ? "laptopcomputer" : "display")
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isTracked ? Color.accentColor : Color.secondary)
                }
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(status.display.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(status.display.name)

                        if isTracked {
                            StatusPill(text: "ACTIVE", color: .accentColor)
                        }
                    }

                    Text(displayDescription)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    playbackSwitch
                    outputPicker
                }
            }

            switch status.availability {
            case .available:
                if let device {
                    availableAudioDetail(device)
                } else {
                    unknownAudioDetail
                }
            case .unavailable:
                unavailableAudioDetail
            case .unknown:
                unknownAudioDetail
            case .unconfigured:
                unconfiguredAudioDetail
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isTracked ? Color.accentColor.opacity(0.065) : Color.primary.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isTracked ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.075),
                    lineWidth: 1
                )
        }
    }

    @ViewBuilder
    private var playbackSwitch: some View {
        if isCurrentSystemOutput {
            Label("In use", systemImage: "checkmark.circle.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.green.opacity(0.10))
                }
                .help("This monitor's audio output is in use")
                .accessibilityLabel("This monitor's audio output is in use")
        } else {
            Button(action: onSwitchOutput) {
                Image(systemName: autoRoutingEnabled ? "lock.fill" : "play.fill")
                    .font(.caption2.weight(.bold))
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(autoRoutingEnabled ? Color.secondary : Color.accentColor)
            .background {
                Circle()
                    .fill(Color.primary.opacity(0.055))
            }
            .clipShape(Circle())
            .disabled(autoRoutingEnabled || device?.isRoutable != true)
            .help(playbackSwitchHelp)
            .accessibilityLabel("Use \(status.display.name) for audio playback")
            .accessibilityHint(playbackSwitchHelp)
        }
    }

    private var playbackSwitchHelp: String {
        if autoRoutingEnabled {
            return "Turn off Auto to switch outputs manually"
        }

        if device?.isRoutable != true {
            return "Choose an available audio output for this monitor first"
        }

        return "Use this monitor's audio output now"
    }

    private var outputPicker: some View {
        Menu {
            Text("Route this monitor to")

            if availableDevices.isEmpty {
                Button("No audio outputs available") {}
                    .disabled(true)
            } else {
                ForEach(availableDevices) { candidate in
                    Button {
                        onSelectDevice(candidate.uid)
                    } label: {
                        if candidate.uid == status.mappedDeviceUID {
                            Label(candidate.displayName, systemImage: "checkmark")
                        } else {
                            Text(candidate.displayName)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background {
                    Circle()
                        .fill(Color.primary.opacity(0.055))
                }
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose an audio output for \(status.display.name)")
        .accessibilityLabel("Choose an audio output for \(status.display.name)")
    }

    private func availableAudioDetail(_ device: AudioOutputDevice) -> some View {
        AdjustableVolumeDetail(
            device: device,
            isCurrentSystemOutput: isCurrentSystemOutput,
            onSetVolume: onSetVolume
        )
    }
}

private struct AdjustableVolumeDetail: View {
    let device: AudioOutputDevice
    let isCurrentSystemOutput: Bool
    let onSetVolume: (Float) -> Void

    @StateObject private var interaction = VolumeSliderInteraction()

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Divider()
                .opacity(0.5)

            HStack(spacing: 8) {
                Image(systemName: speakerSymbol(for: device.volumeState))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(device.volumeState.isMuted ? Color.orange : Color.accentColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(device.displayName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(device.displayName)

                        if isCurrentSystemOutput {
                            StatusPill(text: "SYSTEM", color: .green)
                        }
                    }

                    Text(volumeDescription(
                        for: device.volumeState,
                        draftLevel: device.canSetVolume ? interaction.level : nil
                    ))
                        .font(.caption2)
                        .foregroundStyle(device.volumeState.isMuted ? Color.orange : Color.secondary)
                }

                Spacer(minLength: 8)

                volumeValue(for: device.volumeState, draftLevel: interaction.level)
            }

            if device.canSetVolume, device.volumeState.level != nil {
                Slider(
                    value: Binding(
                        get: { Double(interaction.level) },
                        set: { newValue in
                            interaction.setDraft(Float(newValue), send: onSetVolume)
                        }
                    ),
                    in: 0...1,
                    step: 0.01,
                    onEditingChanged: { isEditing in
                        interaction.setEditing(isEditing, send: onSetVolume)
                    }
                )
                .controlSize(.small)
                .tint(device.volumeState.isMuted ? .orange : .accentColor)
                .accessibilityLabel("Volume for \(device.displayName)")
                .accessibilityValue("\(Int((interaction.level * 100).rounded())) percent")
                .accessibilityHint(device.volumeState.isMuted ? "The device is currently muted" : "")
            } else if let level = device.volumeState.level {
                VolumeBar(level: level, isMuted: device.volumeState.isMuted)
            }
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            interaction.synchronize(with: device.volumeState.level ?? 0)
        }
        .onChange(of: device.uid) { _, _ in
            interaction.reset(to: device.volumeState.level ?? 0)
        }
        .onChange(of: device.volumeState) { _, newState in
            interaction.synchronize(with: newState.level ?? interaction.level)
        }
        .onDisappear {
            interaction.cancelPendingWrite()
        }
    }

    @ViewBuilder
    private func volumeValue(for state: AudioVolumeState, draftLevel: Float) -> some View {
        if state.isMuted {
            Text("MUTED")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        } else if device.canSetVolume, state.level != nil {
            Text("\(Int((draftLevel.clampedToUnitInterval * 100).rounded()))%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        } else if let percentage = state.percentage {
            Text("\(percentage)%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
        } else if state.isDeviceControlled {
            Text("DEVICE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        } else {
            Text("UNKNOWN")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
    }
}

private extension MonitorCard {
    var unavailableAudioDetail: some View {
        audioIssueDetail(
            title: "Cannot output audio",
            description: unavailableDescription,
            symbol: "speaker.slash.fill",
            color: .orange
        )
    }

    var unknownAudioDetail: some View {
        audioIssueDetail(
            title: "Audio availability unknown",
            description: status.inventoryIsAvailable
                ? "Soniqo could not verify that the mapped device can be selected."
                : "Soniqo could not read the current audio device inventory.",
            symbol: "questionmark.circle.fill",
            color: .orange
        )
    }

    @ViewBuilder
    var unconfiguredAudioDetail: some View {
        if availableDevices.isEmpty, hasUnknownDevices {
            audioIssueDetail(
                title: "Audio availability unknown",
                description: "Connected audio devices could not be verified as routable.",
                symbol: "questionmark.circle.fill",
                color: .orange
            )
        } else if availableDevices.isEmpty {
            audioIssueDetail(
                title: "Cannot output audio",
                description: "No routable audio output is currently available to Soniqo.",
                symbol: "speaker.slash.fill",
                color: .orange
            )
        } else {
            audioIssueDetail(
                title: "Audio output not configured",
                description: "Choose an available output for this monitor.",
                symbol: "speaker.badge.exclamationmark.fill",
                color: .secondary
            )
        }
    }

    func audioIssueDetail(
        title: String,
        description: String,
        symbol: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 16, height: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.075))
        }
        .accessibilityElement(children: .combine)
    }

    var displayDescription: String {
        if status.display.isBuiltIn {
            return status.display.isMain ? "Main display · Built-in" : "Built-in display"
        }

        return status.display.isMain ? "Main display" : "Connected display"
    }

    var unavailableDescription: String {
        if status.hasDisconnectedMapping {
            return "The selected audio device is disconnected or unavailable."
        }

        if status.outputDevice != nil {
            return "The mapped device cannot be used as the system output."
        }

        return "No compatible audio output is mapped to this monitor."
    }

}

private struct VolumeBar: View {
    let level: Float
    let isMuted: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.075))

                Capsule()
                    .fill(isMuted ? Color.orange.opacity(0.55) : Color.accentColor.opacity(0.78))
                    .frame(width: proxy.size.width * normalizedLevel)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private var normalizedLevel: CGFloat {
        CGFloat(min(max(level, 0), 1))
    }
}

private struct EmptyMonitorCard: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("No monitors detected")
                    .font(.subheadline.weight(.semibold))

                Text("Connect a display, then refresh Soniqo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(13)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.15), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SectionHeading: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .tracking(0.65)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .tracking(0.35)
            }
        }
        .padding(.horizontal, 2)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(color.opacity(0.11))
            }
    }
}

private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.medium))
            .foregroundStyle(configuration.isPressed ? Color.primary : Color.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.09 : 0.045))
            }
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct ScrollContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

@MainActor
private final class MenuBarLayoutState: ObservableObject {
    @Published var contentHeight: CGFloat = 440
    @Published var maximumHeight: CGFloat = 560
}

@MainActor
private final class VolumeSliderInteraction: ObservableObject {
    @Published private(set) var level: Float = 0

    private var isEditing = false
    private var pendingWrite: DispatchWorkItem?

    func synchronize(with newLevel: Float) {
        guard !isEditing, pendingWrite == nil else {
            return
        }

        level = newLevel.clampedToUnitInterval
    }

    func reset(to newLevel: Float) {
        cancelPendingWrite()
        level = newLevel.clampedToUnitInterval
    }

    func setDraft(_ newLevel: Float, send: @escaping (Float) -> Void) {
        level = newLevel.clampedToUnitInterval
        pendingWrite?.cancel()

        let finalLevel = level
        let workItem = DispatchWorkItem { [weak self] in
            self?.pendingWrite = nil
            send(finalLevel)
        }
        pendingWrite = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    func setEditing(_ editing: Bool, send: (Float) -> Void) {
        isEditing = editing
        guard !editing else {
            return
        }

        pendingWrite?.cancel()
        pendingWrite = nil
        send(level)
    }

    func cancelPendingWrite() {
        pendingWrite?.cancel()
        pendingWrite = nil
        isEditing = false
    }
}

private func speakerSymbol(for state: AudioVolumeState) -> String {
    if state.isMuted {
        return "speaker.slash.fill"
    }

    if state.isUnknown {
        return "speaker.badge.exclamationmark.fill"
    }

    guard let percentage = state.percentage else {
        return "speaker.wave.2.fill"
    }

    switch percentage {
    case 0:
        return "speaker.fill"
    case 1..<34:
        return "speaker.wave.1.fill"
    case 34..<67:
        return "speaker.wave.2.fill"
    default:
        return "speaker.wave.3.fill"
    }
}

private func volumeDescription(for state: AudioVolumeState, draftLevel: Float? = nil) -> String {
    if state.isMuted {
        if let percentage = state.percentage {
            return "Muted · volume set to \(percentage)%"
        }

        return "Muted on the audio device"
    }

    if let draftLevel {
        return "Current volume \(Int((draftLevel.clampedToUnitInterval * 100).rounded()))%"
    }

    if let percentage = state.percentage {
        return "Current volume \(percentage)%"
    }

    if state.isDeviceControlled {
        return "Volume is controlled by the display or receiver"
    }

    return "Current volume could not be read"
}

private extension Float {
    var clampedToUnitInterval: Float {
        min(max(self, 0), 1)
    }
}
