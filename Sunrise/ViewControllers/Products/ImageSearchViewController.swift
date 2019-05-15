//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

class ImageSearchViewController: UIViewController {

    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var collectionView: UICollectionView!

    let imagePickerController = UIImagePickerController()
    private var liveViewCell: LiveViewCell?
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

        disposables += viewModel.reloadItemsSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.collectionView.reloadItems(at: $0)
        }
    }

    private func startCaptureSessionAndPreview() {
        guard let captureSession = CaptureSessionManager.shared.captureSession, let previewLayer = CaptureSessionManager.shared.previewLayer else { return }
        captureSession.sessionPreset = .photo

        if !captureSession.isRunning {
            captureSession.startRunning()
        }

        guard let liveViewCell = liveViewCell else { return }
        DispatchQueue.main.async {
            previewLayer.removeFromSuperlayer()
            previewLayer.frame = liveViewCell.liveView.layer.bounds
            liveViewCell.liveView.layer.addSublayer(previewLayer)
        }
    }

    private func stopCaptureSession() {
        guard let captureSession = CaptureSessionManager.shared.captureSession else { return }

        if captureSession.isRunning, CaptureSessionManager.shared.previewLayer?.superlayer == liveViewCell?.liveView.layer {
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
            return liveViewCell!
        case .image:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as? PhotoCell else { return UICollectionViewCell() }
            cell.imageView.image = nil
            cell.selectedIconImageView.isHidden = viewModel.isSelectedIndicatorHidden(at: indexPath)
            cell.selectedOverlayView.alpha = viewModel.isSelectedIndicatorHidden(at: indexPath) ? 0 : 0.8
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
        guard indexPath.item != 0 else { return }
        viewModel?.selectedItemIndexPath.value = indexPath
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
