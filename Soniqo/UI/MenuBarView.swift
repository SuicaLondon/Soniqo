import SwiftUI

struct MenuBarView: View {
    @ObservedObject var controller: SoniqoController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider()

            status

            Divider()

            footer
        }
        .frame(width: 320)
        .padding(12)
        .onAppear {
            controller.refreshInventory()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Soniqo")
                    .font(.headline)
                Text("System output follows the active window screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { controller.isEnabled },
                set: { controller.setEnabled($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
    }

    private var footer: some View {
        Button(role: .destructive) {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit Soniqo", systemImage: "power")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MenuActionButtonStyle())
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(controller.isEnabled ? "Automatic switching enabled" : "Automatic switching disabled",
                  systemImage: controller.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.subheadline)

            if let window = controller.trackedWindow {
                LabeledContent("Window", value: window.displayName)
            }

            if let display = controller.trackedDisplay {
                LabeledContent("Screen", value: display.name)
            }

            if let device = controller.defaultOutputDevice {
                LabeledContent("Current output", value: device.displayName)
            }

            LabeledContent("Outputs found", value: String(controller.outputDevices.count))
            LabeledContent("Audible processes", value: String(controller.audibleProcesses.count))
            if !controller.audibleProcesses.isEmpty {
                Text(controller.audibleProcesses.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            LabeledContent("Playback windows", value: String(controller.playbackWindows.count))

            Text(controller.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }
}

private struct MenuActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(.red)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.red.opacity(configuration.isPressed ? 0.18 : 0.10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.red.opacity(configuration.isPressed ? 0.35 : 0.20), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
