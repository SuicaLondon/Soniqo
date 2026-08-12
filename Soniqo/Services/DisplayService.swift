import AppKit
import CoreGraphics
import Foundation

final class DisplayService {
    func displays() -> [DisplayInfo] {
        let screens = NSScreen.screens.compactMap { screen -> (displayID: CGDirectDisplayID, screen: NSScreen)? in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }

            return (displayID, screen)
        }

        let hardwareIdentityCounts = Dictionary(
            grouping: screens,
            by: { hardwareIdentity(for: $0.displayID) }
        ).mapValues(\.count)

        return screens.map { entry in
            let identity = hardwareIdentity(for: entry.displayID)
            let persistentID = hardwareIdentityCounts[identity] == 1
                ? identity
                : "\(identity)-session:\(entry.displayID)"

            return DisplayInfo(
                id: entry.displayID,
                name: entry.screen.localizedName,
                frame: CGDisplayBounds(entry.displayID),
                isBuiltIn: CGDisplayIsBuiltin(entry.displayID) != 0,
                isMain: CGDisplayIsMain(entry.displayID) != 0,
                persistentID: persistentID
            )
        }
        .sorted { left, right in
            if left.isMain != right.isMain {
                return left.isMain
            }

            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
    }

    private func hardwareIdentity(for displayID: CGDirectDisplayID) -> String {
        let vendor = CGDisplayVendorNumber(displayID)
        let model = CGDisplayModelNumber(displayID)
        let serial = CGDisplaySerialNumber(displayID)

        guard vendor != 0 || model != 0 || serial != 0 else {
            return "display-id:\(displayID)"
        }

        return "display:\(vendor)-\(model)-\(serial)"
    }

    func display(containingLargestAreaOf windowFrame: CGRect, in displays: [DisplayInfo]) -> DisplayInfo? {
        displays
            .map { display in
                (display: display, area: display.frame.intersection(windowFrame).area)
            }
            .filter { !$0.area.isZero }
            .max { $0.area < $1.area }?
            .display
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
