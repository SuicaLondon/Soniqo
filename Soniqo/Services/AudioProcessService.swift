import AppKit
import CoreAudio
import Foundation

enum AudioProcessError: LocalizedError {
    case coreAudio(OSStatus, String)

    var errorDescription: String? {
        switch self {
        case .coreAudio(let status, let operation):
            return "\(operation) failed with Core Audio status \(status)."
        }
    }
}

final class AudioProcessService {
    func runningOutputProcesses() throws -> [AudioProcess] {
        let processObjectIDs: [AudioObjectID] = try readObjectArray(
            objectID: AudioObjectID(kAudioObjectSystemObject),
            selector: kAudioHardwarePropertyProcessObjectList,
            scope: kAudioObjectPropertyScopeGlobal,
            element: kAudioObjectPropertyElementMain
        )

        return try processObjectIDs.compactMap { processObjectID in
            guard try readUInt32(
                objectID: processObjectID,
                selector: kAudioProcessPropertyIsRunningOutput,
                scope: kAudioObjectPropertyScopeGlobal
            ) != 0 else {
                return nil
            }

            let rawPID = try readPID(processObjectID: processObjectID)
            guard rawPID > 0 else {
                return nil
            }

            let bundleID = try? readString(
                objectID: processObjectID,
                selector: kAudioProcessPropertyBundleID,
                scope: kAudioObjectPropertyScopeGlobal
            )

            let runningApplication = NSRunningApplication(processIdentifier: rawPID)
            let name = runningApplication?.localizedName
                ?? bundleID
                ?? "PID \(rawPID)"

            return AudioProcess(id: rawPID, bundleID: bundleID, name: name)
        }
    }

    private func readPID(processObjectID: AudioObjectID) throws -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var pid = pid_t(0)
        var size = UInt32(MemoryLayout<pid_t>.size)
        let status = AudioObjectGetPropertyData(processObjectID, &address, 0, nil, &size, &pid)
        guard status == noErr else {
            throw AudioProcessError.coreAudio(status, "Read audio process PID")
        }

        return pid
    }

    private func readUInt32(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) throws -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        guard status == noErr else {
            throw AudioProcessError.coreAudio(status, "Read Core Audio process flag")
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
            throw AudioProcessError.coreAudio(status, "Read Core Audio process list size")
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
            throw AudioProcessError.coreAudio(status, "Read Core Audio process list")
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
            throw AudioProcessError.coreAudio(status, "Read Core Audio process bundle ID")
        }

        return value as String? ?? ""
    }
}
