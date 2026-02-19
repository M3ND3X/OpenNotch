// VolumeProvider - CoreAudio system volume. Sends to Rust via VolumeChanged.
// TODO: Use AudioToolbox kAudioHardwareServiceDeviceProperty_VirtualMasterVolume for full implementation.

import Foundation

enum VolumeProvider {
    @MainActor
    static func fetchAndDispatch(appModel: AppModel) {
        // Stub: full implementation would use AudioObjectGetPropertyData with CoreAudio
        appModel.dispatch(.volumeChanged(level: 0.5))
    }
}
