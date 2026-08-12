import Foundation

enum AudioMuteState: Hashable {
    case muted
    case unmuted
    case unknown
}

enum AudioVolumeState: Hashable {
    case level(Float, muteState: AudioMuteState)
    case deviceControlled(muteState: AudioMuteState)
    case unknown(muteState: AudioMuteState)

    var muteState: AudioMuteState {
        switch self {
        case .level(_, let muteState),
             .deviceControlled(let muteState),
             .unknown(let muteState):
            return muteState
        }
    }

    var isMuted: Bool {
        muteState == .muted
    }

    var percentage: Int? {
        guard let level else {
            return nil
        }

        return Int((level.clampedToUnitInterval * 100).rounded())
    }

    var level: Float? {
        guard case .level(let level, _) = self else {
            return nil
        }

        return level.clampedToUnitInterval
    }

    var isDeviceControlled: Bool {
        guard case .deviceControlled = self else {
            return false
        }

        return true
    }

    var isUnknown: Bool {
        guard case .unknown = self else {
            return false
        }

        return true
    }
}

enum AudioVolumeControlAvailability: Hashable {
    case available
    case unavailable
    case unknown
}

enum AudioRoutingAvailability: Hashable {
    case available
    case unavailable
    case unknown
}

struct AudioOutputDevice: Identifiable, Hashable {
    let id: UInt32
    let uid: String
    let name: String
    let isAlive: Bool?
    let canBeDefaultOutput: Bool?
    let isBuiltIn: Bool
    let volumeState: AudioVolumeState
    let volumeControlAvailability: AudioVolumeControlAvailability

    var displayName: String {
        name.isEmpty ? uid : name
    }

    var routingAvailability: AudioRoutingAvailability {
        if isAlive == false || canBeDefaultOutput == false {
            return .unavailable
        }

        if isAlive == true, canBeDefaultOutput == true {
            return .available
        }

        return .unknown
    }

    var isRoutable: Bool {
        routingAvailability == .available
    }

    var canSetVolume: Bool {
        volumeControlAvailability == .available
    }

    func replacingVolumeState(_ volumeState: AudioVolumeState) -> AudioOutputDevice {
        AudioOutputDevice(
            id: id,
            uid: uid,
            name: name,
            isAlive: isAlive,
            canBeDefaultOutput: canBeDefaultOutput,
            isBuiltIn: isBuiltIn,
            volumeState: volumeState,
            volumeControlAvailability: volumeControlAvailability
        )
    }
}

private extension Float {
    var clampedToUnitInterval: Float {
        min(max(self, 0), 1)
    }
}
