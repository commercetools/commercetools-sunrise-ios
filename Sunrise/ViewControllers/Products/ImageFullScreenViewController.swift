//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import UIKit
import AVFoundation
import ReactiveCocoa
import ReactiveSwift
import Result

class ImageFullScreenViewController: UIViewController {

    @IBOutlet weak var liveView: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!

    private let photoOutput = AVCapturePhotoOutput()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: ImageFullScreenViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = ImageFullScreenViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        self.startCaptureSessionAndPreview()
    }

    override func viewDidDisappear(_ animated: Bool) {
        self.stopCaptureSession()

        super.viewDidDisappear(animated)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        disposables += imageView.reactive.image <~ viewModel.capturedImage
        disposables += imageView.reactive.isHidden <~ viewModel.capturedImage.map { $0 == nil }
        disposables += takePhotoButton.reactive.isHidden <~ viewModel.isTakePhotoButtonHidden
        disposables += searchButton.reactive.isHidden <~ viewModel.isSearchButtonHidden


    }

    private func startCaptureSessionAndPreview() {
        guard let captureSession = CaptureSessionManager.shared.captureSession, let previewLayer = CaptureSessionManager.shared.previewLayer, captureSession.canAddOutput(photoOutput) else { return }
        captureSession.addOutput(photoOutput)
        captureSession.sessionPreset = .photo

        if !captureSession.isRunning {
            captureSession.startRunning()
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.removeFromSuperlayer()
        previewLayer.frame = self.liveView.layer.bounds
        self.liveView.layer.addSublayer(previewLayer)
        CATransaction.commit()
    }

    private func stopCaptureSession() {
        guard let captureSession = CaptureSessionManager.shared.captureSession else { return }

        if captureSession.isRunning, CaptureSessionManager.shared.previewLayer?.superlayer == liveView.layer {
            captureSession.stopRunning()
        }

        captureSession.removeOutput(photoOutput)
    }

    @IBAction func takePhoto(_ sender: UIButton) {
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]), delegate: self)
    }

    @IBAction func closeFullScreenView(_ sender: UIButton) {
        dismiss(animated: true)
    }
}

extension ImageFullScreenViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        viewModel?.capturedImage.value = UIImage(data: data)
    }
}
