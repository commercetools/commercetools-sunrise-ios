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

    private var captureSession: AVCaptureSession? = AVCaptureSession()
    private let videoCaptureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
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

        setupCaptureSessionAndPreview()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let captureSession = captureSession, !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    /**
        Method used to setup video input from camera, add input and output to the session.
    */
    private func setupCaptureSessionAndPreview() {
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice), let captureSession = captureSession,
                captureSession.canAddInput(videoInput) && captureSession.canAddOutput(metadataOutput) else {
            self.captureSession = nil
            presentCaptureError()
            return
        }

        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        view.layer.addSublayer(previewLayer!)

        viewModel?.isCapturing.value = true
    }

    /**
        Method used to present errors related to capture device capabilities and permissions.
    */
    private func presentCaptureError() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)

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
                _ = self.navigationController?.popViewController(animated: true)
            }))
        }
        alertController.addAction(UIAlertAction(title: viewModel?.okAction, style: .default, handler: { _ in
            _ = self.navigationController?.popViewController(animated: true)
        }))

        present(alertController, animated: true, completion: nil)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ isLoading in
            if isLoading {
                SVProgressHUD.show()
            } else {
                SVProgressHUD.dismiss()
            }
        })

        viewModel.isCapturing.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isCapturing in
            if isCapturing {
                self?.captureSession?.startRunning()
            } else {
                self?.captureSession?.stopRunning()
            }
        })

        viewModel.scannedProduct.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] scannedProduct in
            if scannedProduct != nil {
                self?.performSegue(withIdentifier: "showScannedProduct", sender: self)
            }
        })

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let productViewController = segue.destination as? ProductViewController, let viewModel = viewModel,
                let product = viewModel.scannedProduct.value {
            let productDetailsViewModel = ProductViewModel(product: product)
            productViewController.viewModel = productDetailsViewModel
        }
    }

}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        if let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let viewModel = viewModel {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            viewModel.scannedCode.value = readableObject.stringValue
        }
    }

}
