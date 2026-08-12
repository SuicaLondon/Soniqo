import CoreGraphics
import Foundation

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    let name: String
    let frame: CGRect
    let isBuiltIn: Bool
    let isMain: Bool
    let persistentID: String

    var storageKey: String {
        persistentID
    }

    var legacyStorageKey: String {
        String(id)
    }
}
