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
    @IBOutlet weak var removeButton: UIButton!
    @IBOutlet weak var chooseAnotherPictureButton: UIButton!
    @IBOutlet weak var dismissButton: UIButton!

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let capturePhotoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
    private let sampleBufferQueue = DispatchQueue.global(qos: .userInteractive)
    private var isCapturing = false
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
        disposables += takePhotoButton.reactive.isHidden <~ viewModel.isTakePhotoButtonHidden
        disposables += searchButton.reactive.isHidden <~ viewModel.isSearchButtonHidden
        disposables += removeButton.reactive.isHidden <~ viewModel.isRemoveButtonHidden
        disposables += chooseAnotherPictureButton.reactive.isHidden <~ viewModel.isChooseAnotherPictureButtonHidden
        disposables += dismissButton.reactive.image(for: .normal) <~ viewModel.dismissButtonImage
    }

    private func startCaptureSessionAndPreview() {
        CaptureSessionManager.shared.sessionQueue.async {
            guard let captureSession = CaptureSessionManager.shared.captureSession, let previewLayer = CaptureSessionManager.shared.previewLayer, captureSession.canAddOutput(self.photoOutput), captureSession.canAddOutput(self.videoOutput), captureSession.canSetSessionPreset(.photo) else { return }
            
            self.photoOutput.setPreparedPhotoSettingsArray([self.capturePhotoSettings])
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sampleBufferQueue)
            
            captureSession.beginConfiguration()
            captureSession.addOutput(self.photoOutput)
            captureSession.addOutput(self.videoOutput)
            captureSession.sessionPreset = .photo
            
            guard let connection = self.videoOutput.connection(with: .video) else { return }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }
            
            captureSession.commitConfiguration()
            
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
            
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.removeFromSuperlayer()
                previewLayer.frame = self.liveView.layer.bounds
                self.liveView.layer.addSublayer(previewLayer)
                CATransaction.commit()
            }
        }
    }

    private func stopCaptureSession() {
        CaptureSessionManager.shared.sessionQueue.async {
            guard let captureSession = CaptureSessionManager.shared.captureSession else { return }
            
            DispatchQueue.main.async {
                if captureSession.isRunning, CaptureSessionManager.shared.previewLayer?.superlayer == self.liveView.layer {
                    CaptureSessionManager.shared.sessionQueue.async {
                        captureSession.stopRunning()
                    }
                }
            }
            captureSession.removeOutput(self.photoOutput)
            captureSession.removeOutput(self.videoOutput)
        }
    }

    @IBAction func takePhoto(_ sender: UIButton) {
        isCapturing = true
        CaptureSessionManager.shared.sessionQueue.async {
            self.photoOutput.capturePhoto(with: self.capturePhotoSettings, delegate: self)
        }
    }

    @IBAction func closeFullScreenView(_ sender: UIButton) {
        dismiss(animated: true)
    }

    @IBAction func removeImage(_ sender: UIButton) {
        NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.resetSearch, object: nil, userInfo: nil)
        dismiss(animated: true)
    }

    @IBAction func chooseAnotherImage(_ sender: UIButton) {
        AppRouting.resetMainViewControllerState {
            self.viewModel?.presentImageSearchViewObserver?.send(value: ())
        }
        dismiss(animated: true)
    }

    @IBAction func performSearch(_ sender: UIButton) {
        viewModel?.performSearchObserver?.send(value: ())
        dismiss(animated: true)
    }
}

extension ImageFullScreenViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        viewModel?.capturedImage.value = UIImage(data: data)
    }
}

extension ImageFullScreenViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isCapturing else { return }
        DispatchQueue.main.async {
            guard self.imageView.image == nil, let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let ciImage = CIImage(cvPixelBuffer: buffer)
            self.imageView.image = UIImage(ciImage: ciImage)
        }
    }
}
