//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import AVFoundation
import ReactiveCocoa
import ReactiveSwift
import Result
import SDWebImage
import SVProgressHUD

class ScannerViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!

    private var captureSession: AVCaptureSession?
    private let videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)
    private let metadataOutput = AVCaptureMetadataOutput()
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }

    var viewModel: ScannerViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = ScannerViewModel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if captureSession == nil {
            captureSession = AVCaptureSession()
            setupCaptureSessionAndPreview()
        }

        if let captureSession = captureSession, !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    /**
        Method used to setup video input from camera, add input and output to the session.
    */
    private func setupCaptureSessionAndPreview() {
        guard let videoCaptureDevice = videoCaptureDevice, let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession, captureSession.canAddInput(videoInput) && captureSession.canAddOutput(metadataOutput) else {
            self.captureSession = nil
            presentCaptureError()
            return
        }

        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        previewLayer.frame = previewView.layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewView.layer.addSublayer(previewLayer)

        viewModel?.isCapturing.value = true
    }

    /**
        Method used to present errors related to capture device capabilities and permissions.
    */
    private func presentCaptureError() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        let alertController = UIAlertController(
                title: viewModel?.errorTitle,
                message: authorizationStatus == .denied ? viewModel?.permissionError : viewModel?.capabilitiesError,
                preferredStyle: .alert
                )
        if authorizationStatus == .denied {
            alertController.addAction(UIAlertAction(title: viewModel?.settingsAction, style: .cancel, handler: { _ in
                if let appSettingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.shared.open(appSettingsURL)
                }
                SunriseTabBarController.currentlyActive?.selectedIndex = 0
            }))
        }
        alertController.addAction(UIAlertAction(title: viewModel?.okAction, style: .default, handler: { _ in
            SunriseTabBarController.currentlyActive?.selectedIndex = 0
        }))

        present(alertController, animated: true, completion: nil)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss() }

        disposables += viewModel.isCapturing.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in $0 ? self?.captureSession?.startRunning() : self?.captureSession?.stopRunning() }

        disposables += viewModel.scannedProduct.producer
        .observe(on: UIScheduler())
        .startWithValues { scannedProduct in
            if let sku = scannedProduct?.allVariants.first(where: { $0.isMatchingVariant == true })?.sku {
                AppRouting.showProductDetails(for: sku)
            }
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let viewModel = viewModel {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            viewModel.scannedCode.value = readableObject.stringValue! // TODO use CIBarcodeDescriptor after migrating to SDK 11
        }
    }
}