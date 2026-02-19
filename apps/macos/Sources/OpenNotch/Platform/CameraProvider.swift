// CameraProvider - AVFoundation camera list. Stub for now.

import AVFoundation
import Foundation

enum CameraProvider {
    @MainActor
    static func fetchAndDispatch(appModel: AppModel) {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        let devices = discovery.devices
        let json = devices.enumerated().map { index, device in
            ["id": "\(index)", "name": device.localizedName] as [String: Any]
        }
        if let data = try? JSONSerialization.data(withJSONObject: json),
           let str = String(data: data, encoding: .utf8) {
            appModel.dispatch(.cameraListReceived(camerasJson: str))
        } else {
            appModel.dispatch(.cameraListReceived(camerasJson: "[]"))
        }
    }
}
