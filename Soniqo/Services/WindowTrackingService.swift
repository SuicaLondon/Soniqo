import AppKit
import CoreGraphics
import Foundation

final class WindowTrackingService {
    func playbackWindows(audibleProcesses: [AudioProcess]) -> [TrackedWindow] {
        windows(matching: audibleProcesses)
    }

    func foregroundWindow() -> TrackedWindow? {
        guard let frontmostApplication = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return windows(ownerPIDs: [frontmostApplication.processIdentifier]).first
    }

    func window(_ window: TrackedWindow, matches audibleProcesses: [AudioProcess]) -> Bool {
        if audibleProcesses.contains(where: { $0.id == window.ownerPID }) {
            return true
        }

        let windowApplication = NSRunningApplication(processIdentifier: window.ownerPID)
        return audibleProcesses.contains { audioProcess in
            sameApplicationFamily(
                windowBundleID: windowApplication?.bundleIdentifier,
                audioBundleID: audioProcess.bundleID
            ) || sameApplicationName(windowApplication?.localizedName ?? window.ownerName, audioProcess.name)
        }
    }

    private func windows(ownerPIDs: Set<pid_t>) -> [TrackedWindow] {
        windows { ownerPID, _ in
            ownerPIDs.contains(ownerPID)
        }
    }

    private func windows(matching audibleProcesses: [AudioProcess]) -> [TrackedWindow] {
        let audiblePIDs = Set(audibleProcesses.map(\.id))

        return windows { ownerPID, ownerName in
            if audiblePIDs.contains(ownerPID) {
                return true
            }

            guard let windowApplication = NSRunningApplication(processIdentifier: ownerPID) else {
                return audibleProcesses.contains { audioProcess in
                    sameApplicationName(ownerName, audioProcess.name)
                }
            }

            let probe = TrackedWindow(
                windowID: 0,
                ownerPID: ownerPID,
                ownerName: windowApplication.localizedName ?? ownerName,
                title: "",
                frame: .zero
            )
            return window(probe, matches: audibleProcesses)
        }
    }

    private func windows(matches: (pid_t, String) -> Bool) -> [TrackedWindow] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowInfo
            .compactMap { dictionary -> TrackedWindow? in
                guard
                    let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t,
                    let layer = dictionary[kCGWindowLayer as String] as? Int,
                    layer == 0,
                    let windowID = dictionary[kCGWindowNumber as String] as? CGWindowID,
                    let boundsDictionary = dictionary[kCGWindowBounds as String] as? [String: Any],
                    let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
                else {
                    return nil
                }

                let alpha = dictionary[kCGWindowAlpha as String] as? Double ?? 1
                guard alpha > 0, bounds.width > 10, bounds.height > 10 else {
                    return nil
                }

                let ownerName = dictionary[kCGWindowOwnerName as String] as? String
                    ?? "Unknown App"
                guard matches(ownerPID, ownerName) else {
                    return nil
                }

                let title = dictionary[kCGWindowName as String] as? String ?? ""

                return TrackedWindow(
                    windowID: windowID,
                    ownerPID: ownerPID,
                    ownerName: ownerName,
                    title: title,
                    frame: bounds
                )
            }
    }

    private func sameApplicationFamily(windowBundleID: String?, audioBundleID: String?) -> Bool {
        guard let windowBundleID, let audioBundleID else {
            return false
        }

        let windowBase = baseBundleID(windowBundleID)
        let audioBase = baseBundleID(audioBundleID)

        return windowBase == audioBase
            || audioBase.hasPrefix(windowBase + ".")
            || windowBase.hasPrefix(audioBase + ".")
    }

    private func baseBundleID(_ bundleID: String) -> String {
        let lowered = bundleID.lowercased()
        let helperMarkers = [".helper", ".renderer", ".gpu", ".plugin"]

        for marker in helperMarkers {
            if let range = lowered.range(of: marker) {
                return String(lowered[..<range.lowerBound])
            }
        }

        return lowered
    }

    private func sameApplicationName(_ left: String, _ right: String) -> Bool {
        let leftBase = baseApplicationName(left)
        let rightBase = baseApplicationName(right)

        return leftBase == rightBase
            || leftBase.hasPrefix(rightBase)
            || rightBase.hasPrefix(leftBase)
    }

    private func baseApplicationName(_ name: String) -> String {
        name
            .lowercased()
            .replacingOccurrences(of: " helper", with: "")
            .replacingOccurrences(of: " renderer", with: "")
            .replacingOccurrences(of: " gpu", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else {
            return 0
        }

        return width * height
    }
}
