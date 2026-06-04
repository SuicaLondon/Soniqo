import CoreGraphics
import Foundation

struct TrackedWindow: Equatable {
    let windowID: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let title: String
    let frame: CGRect

    var displayName: String {
        if title.isEmpty {
            return ownerName
        }

        return "\(ownerName) - \(title)"
    }
}
