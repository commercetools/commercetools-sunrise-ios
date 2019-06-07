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

        CaptureSessionManager.shared.sessionQueue.async {
            guard let captureSession = CaptureSessionManager.shared.captureSession else { return }
            
            captureSession.removeOutput(self.metadataOutput)
            
            DispatchQueue.main.async {
                if captureSession.isRunning, CaptureSessionManager.shared.previewLayer?.superlayer == self.previewView.layer {
                    CaptureSessionManager.shared.sessionQueue.async {
                        captureSession.stopRunning()
                    }
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        startCaptureSessionAndPreview()
    }

    /**
        Method used to setup video input from camera, add input and output to the session.
    */
    private func startCaptureSessionAndPreview() {
        CaptureSessionManager.shared.sessionQueue.async {
            guard let captureSession = CaptureSessionManager.shared.captureSession, let previewLayer = CaptureSessionManager.shared.previewLayer, captureSession.canAddOutput(self.metadataOutput) else { return }
            
            captureSession.addOutput(self.metadataOutput)
            
            self.metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            self.metadataOutput.metadataObjectTypes = self.metadataOutput.availableMetadataObjectTypes
            
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
            
            DispatchQueue.main.async {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.removeFromSuperlayer()
                previewLayer.frame = self.previewView.layer.bounds
                self.previewView.layer.addSublayer(previewLayer)
                CATransaction.commit()
            }
            
            self.viewModel?.isCapturing.value = true
        }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss() }

        disposables += viewModel.isCapturing.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? CaptureSessionManager.shared.captureSession?.startRunning() : CaptureSessionManager.shared.captureSession?.stopRunning() }

        disposables += viewModel.scannedProduct.producer
        .observe(on: UIScheduler())
        .startWithValues { scannedProduct in
            if let sku = scannedProduct?.allVariants.first(where: { $0.isMatchingVariant == true })?.sku {
                AppRouting.showProductDetails(sku: sku)
            }
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let viewModel = viewModel {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            viewModel.scannedCode.value = readableObject.stringValue! // TODO use CIBarcodeDescriptor after migrating to SDK 11
        }
    }
}