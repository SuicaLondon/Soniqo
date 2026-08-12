import CoreAudio
import Foundation

enum AudioOutputError: LocalizedError {
    case missingDeviceUID(String)
    case unavailableDevice(String)
    case volumeControlUnavailable(String)
    case volumeControlUnknown(String)
    case unreadableOutputStreams(AudioDeviceID)
    case coreAudio(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case .missingDeviceUID(let uid):
            return "Output device is no longer available: \(uid)"
        case .unavailableDevice(let name):
            return "\(name) cannot be used as the system output right now."
        case .volumeControlUnavailable(let name):
            return "\(name)'s volume is controlled by the audio device."
        case .volumeControlUnknown(let name):
            return "Soniqo could not verify volume control for \(name)."
        case .unreadableOutputStreams(let deviceID):
            return "Soniqo could not inspect audio output device \(deviceID)."
        case .coreAudio(let status, let operation):
            return "\(operation) failed with Core Audio status \(status)."
        }
    }
}

final class AudioOutputService {
    func outputDevices() throws -> [AudioOutputDevice] {
        let deviceIDs: [AudioDeviceID] = try readObjectArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyDevices,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )

        return try deviceIDs.compactMap { deviceID in
            let deviceHasOutputStreams: Bool
            do {
                deviceHasOutputStreams = try hasOutputStreams(deviceID: deviceID)
            } catch {
                throw AudioOutputError.unreadableOutputStreams(deviceID)
            }

            guard deviceHasOutputStreams else {
                return nil
            }

            let name = (try? readString(
                objectID: deviceID,
                selector: kAudioObjectPropertyName,
                scope: kAudioObjectPropertyScopeGlobal
            )) ?? "Unknown Output"

            let readableUID = try? readString(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
            )
            let hasStableUID = readableUID?.isEmpty == false
            let uid = hasStableUID ? readableUID! : String(deviceID)

            let isAlive = boolProperty(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceIsAlive,
                scope: kAudioObjectPropertyScopeGlobal
            )
            let canBeDefaultOutput = boolProperty(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceCanBeDefaultDevice,
                scope: kAudioObjectPropertyScopeOutput
            )
            let transportType = (try? readUInt32(
                objectID: deviceID,
                selector: kAudioDevicePropertyTransportType,
                scope: kAudioObjectPropertyScopeGlobal,
                element: kAudioObjectPropertyElementMain
            )) ?? kAudioDeviceTransportTypeUnknown

            return AudioOutputDevice(
                id: deviceID,
                uid: uid,
                name: name,
                isAlive: isAlive,
                canBeDefaultOutput: canBeDefaultOutput,
                isBuiltIn: transportType == kAudioDeviceTransportTypeBuiltIn,
                volumeState: volumeState(deviceID: deviceID),
                volumeControlAvailability: hasStableUID
                    ? volumeControlAvailability(deviceID: deviceID)
                    : .unknown
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func defaultOutputDevice() throws -> AudioOutputDevice? {
        let devices = try outputDevices()
        return try defaultOutputDevice(in: devices)
    }

    func defaultOutputDevice(in devices: [AudioOutputDevice]) throws -> AudioOutputDevice? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )

        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Read default output device")
        }

        return devices.first { $0.id == deviceID }
    }

    func setDefaultOutputDevice(uid: String) throws {
        let devices = try outputDevices()
        guard let device = devices.first(where: { $0.uid == uid }) else {
            throw AudioOutputError.missingDeviceUID(uid)
        }
        guard device.isRoutable else {
            throw AudioOutputError.unavailableDevice(device.displayName)
        }

        try setDefaultOutputDevice(device.id)
    }

    func setVolume(_ level: Float, for device: AudioOutputDevice) throws {
        guard level.isFinite else {
            throw AudioOutputError.volumeControlUnknown(device.displayName)
        }

        let deviceID = try deviceID(forUID: device.uid)
        let normalizedLevel = level.clampedToUnitInterval
        let masterElement = kAudioObjectPropertyElementMain

        let masterCapability = propertyWriteCapability(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioObjectPropertyScopeOutput,
            element: masterElement
        )
        switch masterCapability {
        case .settable:
            try setFloat32Property(
                normalizedLevel,
                objectID: deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: masterElement,
                operation: "Set \(device.displayName) volume"
            )
            return
        case .failed:
            throw AudioOutputError.volumeControlUnknown(device.displayName)
        case .readOnly, .absent:
            break
        }

        let channelElements = preferredOutputChannelElements(deviceID: deviceID)
        var writableChannelElements: [AudioObjectPropertyElement] = []
        for element in channelElements {
            switch propertyWriteCapability(
                objectID: deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: element
            ) {
            case .settable:
                writableChannelElements.append(element)
            case .readOnly:
                throw AudioOutputError.volumeControlUnavailable(device.displayName)
            case .failed:
                throw AudioOutputError.volumeControlUnknown(device.displayName)
            case .absent:
                throw AudioOutputError.volumeControlUnavailable(device.displayName)
            }
        }

        guard !writableChannelElements.isEmpty else {
            throw AudioOutputError.volumeControlUnavailable(device.displayName)
        }

        for element in writableChannelElements {
            try setFloat32Property(
                normalizedLevel,
                objectID: deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: element,
                operation: "Set \(device.displayName) volume"
            )
        }

    }

    private func deviceID(forUID uid: String) throws -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslateUIDToDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceUID = uid as CFString
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = withUnsafePointer(to: &deviceUID) { uidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                uidPointer,
                &size,
                &deviceID
            )
        }

        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Find audio output by UID")
        }
        guard deviceID != AudioDeviceID(kAudioObjectUnknown) else {
            throw AudioOutputError.missingDeviceUID(uid)
        }

        return deviceID
    }

    private func setDefaultOutputDevice(_ deviceID: AudioDeviceID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var mutableDeviceID = deviceID
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &mutableDeviceID
        )

        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Set default output device")
        }
    }

    private func hasOutputStreams(deviceID: AudioDeviceID) throws -> Bool {
        let streams: [AudioStreamID] = try readObjectArray(
            objectID: deviceID,
            selector: kAudioDevicePropertyStreams,
            scope: kAudioDevicePropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )

        return !streams.isEmpty
    }

    private func volumeState(deviceID: AudioDeviceID) -> AudioVolumeState {
        let channelElements = preferredOutputChannelElements(deviceID: deviceID)
        let muteState = readMuteState(deviceID: deviceID, channelElements: channelElements)

        switch readFloat32Property(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioObjectPropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        ) {
        case .value(let masterLevel):
            return .level(masterLevel.clampedToUnitInterval, muteState: muteState)
        case .failed:
            return .unknown(muteState: muteState)
        case .absent:
            break
        }

        var channelLevels: [Float32] = []
        for element in channelElements {
            switch readFloat32Property(
                objectID: deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: element
            ) {
            case .value(let level):
                channelLevels.append(level)
            case .failed:
                return .unknown(muteState: muteState)
            case .absent:
                continue
            }
        }

        guard !channelLevels.isEmpty else {
            return .deviceControlled(muteState: muteState)
        }

        let averageLevel = channelLevels.reduce(0, +) / Float(channelLevels.count)
        return .level(averageLevel.clampedToUnitInterval, muteState: muteState)
    }

    private func volumeControlAvailability(
        deviceID: AudioDeviceID
    ) -> AudioVolumeControlAvailability {
        let masterCapability = propertyWriteCapability(
            objectID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar,
            scope: kAudioObjectPropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )
        switch masterCapability {
        case .settable:
            return .available
        case .failed:
            return .unknown
        case .readOnly, .absent:
            break
        }

        let channelElements = preferredOutputChannelElements(deviceID: deviceID)
        guard !channelElements.isEmpty else {
            return .unavailable
        }

        for element in channelElements {
            switch propertyWriteCapability(
                objectID: deviceID,
                selector: kAudioDevicePropertyVolumeScalar,
                scope: kAudioObjectPropertyScopeOutput,
                element: element
            ) {
            case .settable:
                continue
            case .readOnly:
                return .unavailable
            case .failed:
                return .unknown
            case .absent:
                return .unavailable
            }
        }

        return .available
    }

    private func preferredOutputChannelElements(deviceID: AudioDeviceID) -> [AudioObjectPropertyElement] {
        let preferredChannels: [UInt32] = (try? readObjectArray(
            objectID: deviceID,
            selector: kAudioDevicePropertyPreferredChannelsForStereo,
            scope: kAudioObjectPropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        )) ?? []

        let channels = preferredChannels.isEmpty ? [1, 2] : preferredChannels

        return Array(Set(channels))
            .filter { $0 != kAudioObjectPropertyElementMain }
            .sorted()
    }

    private func readMuteState(
        deviceID: AudioDeviceID,
        channelElements: [AudioObjectPropertyElement]
    ) -> AudioMuteState {
        switch readUInt32Property(
            objectID: deviceID,
            selector: kAudioDevicePropertyMute,
            scope: kAudioObjectPropertyScopeOutput,
            element: kAudioObjectPropertyElementMain
        ) {
        case .value(let masterMute):
            return masterMute == 0 ? .unmuted : .muted
        case .failed:
            return .unknown
        case .absent:
            break
        }

        var channelMuteValues: [UInt32] = []
        for element in channelElements {
            switch readUInt32Property(
                objectID: deviceID,
                selector: kAudioDevicePropertyMute,
                scope: kAudioObjectPropertyScopeOutput,
                element: element
            ) {
            case .value(let value):
                channelMuteValues.append(value)
            case .failed:
                return .unknown
            case .absent:
                continue
            }
        }

        if channelMuteValues.contains(0) {
            return .unmuted
        }

        if channelMuteValues.count == channelElements.count,
           !channelMuteValues.isEmpty {
            return .muted
        }

        return .unknown
    }

    private func boolProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> Bool? {
        guard case .value(let value) = readUInt32Property(
            objectID: objectID,
            selector: selector,
            scope: scope,
            element: kAudioObjectPropertyElementMain
        ) else {
            return nil
        }

        return value != 0
    }

    private func readFloat32Property(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> PropertyRead<Float32> {
        guard hasProperty(objectID: objectID, selector: selector, scope: scope, element: element) else {
            return .absent
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)

        guard status == noErr, value.isFinite else {
            return .failed
        }

        return .value(value)
    }

    private func readUInt32Property(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> PropertyRead<UInt32> {
        guard hasProperty(objectID: objectID, selector: selector, scope: scope, element: element) else {
            return .absent
        }

        do {
            return .value(try readUInt32(
                objectID: objectID,
                selector: selector,
                scope: scope,
                element: element
            ))
        } catch {
            return .failed
        }
    }

    private func hasProperty(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )

        return AudioObjectHasProperty(objectID, &address)
    }

    private func propertyWriteCapability(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) -> PropertyWriteCapability {
        guard hasProperty(
            objectID: objectID,
            selector: selector,
            scope: scope,
            element: element
        ) else {
            return .absent
        }

        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        var isSettable: DarwinBoolean = false
        let status = AudioObjectIsPropertySettable(objectID, &address, &isSettable)

        guard status == noErr else {
            return .failed
        }

        return isSettable.boolValue ? .settable : .readOnly
    }

    private func setFloat32Property(
        _ value: Float32,
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement,
        operation: String
    ) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )
        var mutableValue = value
        let size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(
            objectID,
            &address,
            0,
            nil,
            size,
            &mutableValue
        )

        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, operation)
        }
    }

    private func readUInt32(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )

        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Read Core Audio integer")
        }

        return value
    }

    private func readObjectArray<T>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope,
        element: AudioObjectPropertyElement
    ) throws -> [T] {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: element
        )

        var size: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &size)
        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Read Core Audio data size")
        }

        guard size > 0 else {
            return []
        }

        var data = [UInt8](repeating: 0, count: Int(size))
        status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return OSStatus(kAudioHardwareUnspecifiedError)
            }

            return AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, baseAddress)
        }

        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Read Core Audio object data")
        }

        return data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: T.self))
        }
    }

    private func readString(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, pointer)
        }
        guard status == noErr else {
            throw AudioOutputError.coreAudio(status, "Read Core Audio string")
        }

        return value as String? ?? ""
    }
}

private enum PropertyRead<Value> {
    case absent
    case value(Value)
    case failed
}

private enum PropertyWriteCapability {
    case absent
    case settable
    case readOnly
    case failed
}

private extension Float {
    var clampedToUnitInterval: Float {
        min(max(self, 0), 1)
    }
}
