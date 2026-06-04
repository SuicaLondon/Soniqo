import CoreGraphics
import Foundation

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect

    var storageKey: String {
        String(id)
    }
}
