//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import AVFoundation

class CaptureSessionManager: NSObject {

    /// A shared instance of `CaptureSessionManager`, which should be used by view models.
    static let shared = CaptureSessionManager()

    // MARK: - Properties

    private(set) var captureSession: AVCaptureSession? = AVCaptureSession()
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private let videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)

    // MARK: - Lifecycle

    override private init() {
        super.init()

        guard let videoCaptureDevice = videoCaptureDevice, let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession, captureSession.canAddInput(videoInput) else {
            self.captureSession = nil
            presentCaptureError()
            return
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill

        captureSession.addInput(videoInput)
    }

    private func presentCaptureError() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        let alertController = UIAlertController(
                title: NSLocalizedString("Could not scan", comment: "Scanning error title"),
                message: authorizationStatus == .denied ? NSLocalizedString("In order to scan products, please go to settings and grant Camera permission.", comment: "Camera permissions error") : NSLocalizedString("Your device is not capable of performing barcode scanning.", comment: "Capabilities scanning error"),
                preferredStyle: .alert
        )
        if authorizationStatus == .denied {
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Settings"), style: .cancel, handler: { _ in
                if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettingsURL)
                }
                NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.resetSearch, object: nil, userInfo: nil)
            }))
        }
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK"), style: .default))

        UIApplication.shared.delegate?.window??.rootViewController?.present(alertController, animated: true)
    }
}