import Foundation

struct AudioOutputDevice: Identifiable, Hashable {
    let id: UInt32
    let uid: String
    let name: String

    var displayName: String {
        name.isEmpty ? uid : name
    }
}
