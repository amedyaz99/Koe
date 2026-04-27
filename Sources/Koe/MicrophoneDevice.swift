import CoreAudio
import Foundation

struct MicrophoneDevice: Identifiable, Hashable {
    let id: AudioDeviceID
    let name: String
    let uid: String

    static let systemDefault = MicrophoneDevice(id: 0, name: "System Default", uid: "")

    static func allInputDevices() -> [MicrophoneDevice] {
        var propAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize
        ) == noErr else { return [.systemDefault] }

        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &propAddr, 0, nil, &dataSize, &deviceIDs
        ) == noErr else { return [.systemDefault] }

        var result: [MicrophoneDevice] = [.systemDefault]
        for deviceID in deviceIDs {
            var inputAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddr, 0, nil, &inputSize) == noErr,
                  inputSize > 0 else { continue }

            guard let name = stringProp(deviceID, kAudioDevicePropertyDeviceNameCFString),
                  let uid = stringProp(deviceID, kAudioDevicePropertyDeviceUID),
                  !name.isEmpty else { continue }

            result.append(MicrophoneDevice(id: deviceID, name: name, uid: uid))
        }
        return result
    }

    private static func stringProp(_ deviceID: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &value) == noErr,
              let value else { return nil }
        return value.takeRetainedValue() as String
    }
}
