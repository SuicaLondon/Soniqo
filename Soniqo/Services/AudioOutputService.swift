import CoreAudio
import Foundation

enum AudioOutputError: LocalizedError {
    case missingDeviceUID(String)
    case coreAudio(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case .missingDeviceUID(let uid):
            return "Output device is no longer available: \(uid)"
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
            guard try hasOutputStreams(deviceID: deviceID) else {
                return nil
            }

            let name = (try? readString(
                objectID: deviceID,
                selector: kAudioObjectPropertyName,
                scope: kAudioObjectPropertyScopeGlobal
            )) ?? "Unknown Output"

            let uid = (try? readString(
                objectID: deviceID,
                selector: kAudioDevicePropertyDeviceUID,
                scope: kAudioObjectPropertyScopeGlobal
            )) ?? String(deviceID)

            return AudioOutputDevice(id: deviceID, uid: uid, name: name)
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    func defaultOutputDevice() throws -> AudioOutputDevice? {
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

        return try outputDevices().first { $0.id == deviceID }
    }

    func setDefaultOutputDevice(uid: String) throws {
        let devices = try outputDevices()
        guard let device = devices.first(where: { $0.uid == uid }) else {
            throw AudioOutputError.missingDeviceUID(uid)
        }

        try setDefaultOutputDevice(device.id)
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
