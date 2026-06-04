import Foundation

struct RoutingPreferences: Equatable {
    var isEnabled: Bool
    var screenDeviceUIDs: [String: String]

    static let defaults = RoutingPreferences(
        isEnabled: false,
        screenDeviceUIDs: [:]
    )
}
