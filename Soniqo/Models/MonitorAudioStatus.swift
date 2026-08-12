import Foundation

enum MonitorAudioAvailability: Hashable {
    case available
    case unavailable
    case unknown
    case unconfigured
}

struct MonitorAudioStatus: Identifiable, Hashable {
    let display: DisplayInfo
    let mappedDeviceUID: String?
    let outputDevice: AudioOutputDevice?
    let inventoryIsAvailable: Bool

    var id: DisplayInfo.ID {
        display.id
    }

    var availability: MonitorAudioAvailability {
        guard inventoryIsAvailable else {
            return .unknown
        }

        guard mappedDeviceUID != nil else {
            return .unconfigured
        }

        guard let outputDevice else {
            return .unavailable
        }

        switch outputDevice.routingAvailability {
        case .available:
            return .available
        case .unavailable:
            return .unavailable
        case .unknown:
            return .unknown
        }
    }

    var hasDisconnectedMapping: Bool {
        mappedDeviceUID != nil && outputDevice == nil
    }
}
