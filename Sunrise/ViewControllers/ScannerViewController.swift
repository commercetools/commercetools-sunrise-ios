//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import AVFoundation
import ReactiveCocoa
import Result
import SDWebImage
import SVProgressHUD

class ScannerViewController: UIViewController {

    private let captureSession = AVCaptureSession()
    private let videoCaptureDevice = AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    private let metadataOutput = AVCaptureMetadataOutput()

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

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)

        if captureSession.running {
            captureSession.stopRunning()
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if !captureSession.running {
            captureSession.startRunning()
        }
    }

    /**
        Method used to setup video input from camera, add input and output to the session.
    */
    private func setupCaptureSessionAndPreview() {
        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice)
                where captureSession.canAddInput(videoInput) && captureSession.canAddOutput(metadataOutput) else {
            presentCaptureError()
            return
        }

        captureSession.addInput(videoInput)
        captureSession.addOutput(metadataOutput)

        metadataOutput.setMetadataObjectsDelegate(self, queue: dispatch_get_main_queue())
        metadataOutput.metadataObjectTypes = metadataOutput.availableMetadataObjectTypes

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        view.layer.addSublayer(previewLayer)

        viewModel?.isCapturing.value = true
    }

    /**
        Method used to present errors related to capture device capabilities and permissions.
    */
    private func presentCaptureError() {
        let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)

        let alertController = UIAlertController(
                title: viewModel?.errorTitle,
                message: authorizationStatus == .Denied ? viewModel?.permissionError : viewModel?.capabilitiesError,
                preferredStyle: .Alert
                )
        if authorizationStatus == .Denied {
            alertController.addAction(UIAlertAction(title: "Settings", style: .Cancel, handler: { _ in
                if let appSettingsURL = NSURL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.sharedApplication().openURL(appSettingsURL)
                }
                self.navigationController?.popViewControllerAnimated(true)
            }))
        }
        alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: { _ in
            self.navigationController?.popViewControllerAnimated(true)
        }))

        presentViewController(alertController, animated: true, completion: nil)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ isLoading in
            if isLoading {
                SVProgressHUD.show()
            } else {
                SVProgressHUD.dismiss()
            }
        })

        viewModel.isCapturing.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] isCapturing in
            if isCapturing {
                self?.captureSession.startRunning()
            } else {
                self?.captureSession.stopRunning()
            }
        })

        viewModel.scannedProduct.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] scannedProduct in
            if scannedProduct != nil {
                self?.performSegueWithIdentifier("showScannedProduct", sender: self)
            }
        })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let productViewController = segue.destinationViewController as? ProductViewController, viewModel = viewModel,
                product = viewModel.scannedProduct.value {
            let productDetailsViewModel = ProductViewModel(product: product)
            productViewController.viewModel = productDetailsViewModel
        }
    }

}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {

    func captureOutput(captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [AnyObject]!, fromConnection connection: AVCaptureConnection!) {
        if let readableObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject, viewModel = viewModel {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            viewModel.scannedCode.value = readableObject.stringValue
        }
    }

}