import Foundation

struct AudioProcess: Identifiable, Hashable {
    let id: pid_t
    let bundleID: String?
    let name: String
}
