//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import UIKit
import AVFoundation
import ReactiveCocoa
import ReactiveSwift
import Result

class ImageSearchViewController: UIViewController {

    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var browseImageGalleryButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!

    let imagePickerController = UIImagePickerController()
    private var captureSession: AVCaptureSession?
    private let videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var liveViewCell: LiveViewCell?
    private let photoOutput = AVCapturePhotoOutput()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: ImageSearchViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let collectionViewLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            collectionViewLayout.itemSize = ImageSearchViewModel.itemSize
            collectionViewLayout.minimumLineSpacing = ImageSearchViewModel.itemSpacing
            collectionViewLayout.minimumInteritemSpacing = ImageSearchViewModel.itemSpacing
        }

        imagePickerController.delegate = self
        imagePickerController.sourceType = .photoLibrary

        viewModel = ImageSearchViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DispatchQueue.global(qos: .userInteractive).async {
            self.startCaptureSessionAndPreview()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.stopCaptureSession()
        }

        super.viewDidDisappear(animated)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        disposables += searchButton.reactive.isHidden <~ viewModel.isSearchButtonHidden
        disposables += browseImageGalleryButton.reactive.isHidden <~ viewModel.isBrowseAllButtonHidden

        disposables += viewModel.shouldPresentPhotosAccessDeniedAlert.producer
        .filter { $0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.presentPhotosAccessDeniedAlert()
        }

        disposables += viewModel.reloadCollectionViewSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.collectionView.reloadData()
            self?.startCaptureSessionAndPreview()
        }

        disposables += viewModel.captureImageSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey:AVVideoCodecType.jpeg]), delegate: self)
            self.startCaptureSessionAndPreview()
        }
    }

    private func startCaptureSessionAndPreview() {
        if captureSession == nil {
            captureSession = AVCaptureSession()
            setupCaptureSessionAndPreview()
            DispatchQueue.main.async {
                self.collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
            }
        }

        if let captureSession = captureSession, !captureSession.isRunning {
            captureSession.startRunning()
        }

        guard let captureSession = captureSession, let liveViewCell = liveViewCell else { return }
        guard previewLayer == nil || previewLayer!.superlayer == nil else { return }
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        guard let previewLayer = previewLayer else { return }
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        DispatchQueue.main.async {
            previewLayer.frame = liveViewCell.liveView.layer.bounds
            liveViewCell.liveView.layer.addSublayer(previewLayer)
        }
    }

    private func stopCaptureSession() {
        if let captureSession = captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func presentPhotosAccessDeniedAlert() {
        let alertController = UIAlertController(title: NSLocalizedString("Cannot access photos", comment: "Cannot access photos"), message: NSLocalizedString("Please enable access to photos for Sunrise app", comment: "Photos permission prompt"), preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Settings"), style: .default) { [unowned self] _ in
            self.navigationController?.popViewController(animated: true)
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        alertController.addAction(UIAlertAction(title: viewModel?.okAction, style: .default) { [unowned self] _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alertController, animated: true)
    }

    private func setupCaptureSessionAndPreview() {
        guard let videoCaptureDevice = videoCaptureDevice, let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              let captureSession = captureSession, captureSession.canAddInput(videoInput) && captureSession.canAddOutput(photoOutput) else {
            self.captureSession = nil
            presentCaptureError()
            return
        }

        captureSession.addInput(videoInput)
        captureSession.addOutput(photoOutput)
        captureSession.sessionPreset = .photo
    }

    private func presentCaptureError() {
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        let alertController = UIAlertController(
                title: viewModel?.liveViewErrorTitle,
                message: authorizationStatus == .denied ? viewModel?.cameraPermissionError : viewModel?.capabilitiesError,
                preferredStyle: .alert
        )
        if authorizationStatus == .denied {
            alertController.addAction(UIAlertAction(title: viewModel?.settingsAction, style: .cancel, handler: { _ in
                if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettingsURL)
                }
                NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.resetSearch, object: nil, userInfo: nil)
            }))
        }
        alertController.addAction(UIAlertAction(title: viewModel?.okAction, style: .default))

        present(alertController, animated: true)
    }

    @IBAction func browseImageGallery(_ sender: UIButton) {
        present(imagePickerController, animated: true)
    }
}

extension ImageSearchViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel?.numberOfItems ?? 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel = viewModel else { return UICollectionViewCell() }

        switch viewModel.cellType(at: indexPath) {
        case .liveView:
            if liveViewCell == nil {
                liveViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: "LiveViewCell", for: indexPath) as? LiveViewCell
            }
            liveViewCell!.selectedIconImageView.isHidden = viewModel.isSelectedIndicatorHidden(at: indexPath)
            liveViewCell!.imageView.isHidden = viewModel.capturedImage.value == nil
            liveViewCell!.imageView.image = viewModel.capturedImage.value
            return liveViewCell!
        case .image:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as? PhotoCell else { return UICollectionViewCell() }
            cell.imageView.image = nil
            cell.selectedIconImageView.isHidden = viewModel.isSelectedIndicatorHidden(at: indexPath)
            viewModel.image(at: indexPath, completion: { image in
                let currentIndexPath = collectionView.indexPath(for: cell)
                guard currentIndexPath == nil || currentIndexPath == indexPath else { return }
                cell.imageView.image = image
            })
            return cell
        }
    }
}

extension ImageSearchViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previouslySelectedIndexPath = viewModel?.selectedItemIndexPath.value
        viewModel?.selectedItemIndexPath.value = indexPath
        guard indexPath != previouslySelectedIndexPath else { return }
        var indexPathsToReload = [IndexPath]()
        if let previouslySelectedIndexPath = previouslySelectedIndexPath {
            indexPathsToReload.append(previouslySelectedIndexPath)
        }
        if indexPath.row != 0 {
            indexPathsToReload.append(indexPath)
        }
        collectionView.reloadItems(at: indexPathsToReload)
    }
}

extension ImageSearchViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        viewModel?.prefetchItemsObserver.send(value: indexPaths)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        viewModel?.cancelPrefetchingObserver.send(value: indexPaths)
    }
}

extension ImageSearchViewController: UIImagePickerControllerDelegate {

    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
    }
}

extension ImageSearchViewController: UINavigationControllerDelegate {

}

extension ImageSearchViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        viewModel?.capturedImage.value = UIImage(data: data)
        collectionView.reloadItems(at: [IndexPath(item: 0, section: 0)])
    }
}