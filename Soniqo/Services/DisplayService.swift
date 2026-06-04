import AppKit
import CoreGraphics
import Foundation

final class DisplayService {
    func displays() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }

            return DisplayInfo(
                id: displayID,
                name: screen.localizedName,
                frame: CGDisplayBounds(displayID)
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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
