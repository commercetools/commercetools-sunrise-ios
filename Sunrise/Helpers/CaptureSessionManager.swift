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
}