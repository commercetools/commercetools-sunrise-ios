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
    @IBOutlet weak var gradientView: UIView!

    let imagePickerController = UIImagePickerController()
    private var liveViewCell: LiveViewCell?
    private let gradientLayer = CAGradientLayer()
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
        imagePickerController.allowsEditing = true

        gradientLayer.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 0)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)

        viewModel = ImageSearchViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.startCaptureSessionAndPreview()
    }

    override func viewDidDisappear(_ animated: Bool) {
        self.stopCaptureSession()
        if !(presentedViewController is ImageFullScreenViewController || presentedViewController is UIImagePickerController) {
            viewModel?.dismissObserver.send(value: ())
        }

        super.viewDidDisappear(animated)
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        disposables += searchButton.reactive.isHidden <~ viewModel.isSearchButtonHidden

        disposables += viewModel.shouldPresentPhotosAccessDeniedAlert.producer
        .combineLatest(with: reactive.trigger(for: #selector(viewDidAppear(_:))))
        .filter { $0.0 }
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
        .observeValues { [weak self] indexPaths in
            UIView.performWithoutAnimation {
                self?.collectionView.reloadItems(at: indexPaths)
            }
        }
    }

    private func startCaptureSessionAndPreview() {
        CaptureSessionManager.shared.sessionQueue.async {
            guard let captureSession = CaptureSessionManager.shared.captureSession, let previewLayer = CaptureSessionManager.shared.previewLayer else { return }
            captureSession.sessionPreset = .photo
            
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
            
            DispatchQueue.main.async {
                guard let liveViewCell = self.liveViewCell else { return }
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                previewLayer.removeFromSuperlayer()
                previewLayer.frame = liveViewCell.liveView.layer.bounds
                liveViewCell.liveView.layer.addSublayer(previewLayer)
                CATransaction.commit()
            }
        }
    }

    private func stopCaptureSession() {
        CaptureSessionManager.shared.sessionQueue.async {
            guard let captureSession = CaptureSessionManager.shared.captureSession else { return }
            
            DispatchQueue.main.async {
                if captureSession.isRunning, CaptureSessionManager.shared.previewLayer?.superlayer == self.liveViewCell?.liveView.layer {
                    CaptureSessionManager.shared.sessionQueue.async {
                        captureSession.stopRunning()
                    }
                }
            }
        }
    }

    private func presentPhotosAccessDeniedAlert() {
        let alertController = UIAlertController(title: ImageSearchViewModel.photosAccessDeniedTitle, message: ImageSearchViewModel.photosAccessDeniedMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: ImageSearchViewModel.settingsAction, style: .default) { [unowned self] _ in
            self.navigationController?.popViewController(animated: true)
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        alertController.addAction(UIAlertAction(title: ImageSearchViewModel.okAction, style: .default) { [unowned self] _ in
            self.navigationController?.popViewController(animated: true)
        })
        present(alertController, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let imageFullScreenViewController = segue.destination as? ImageFullScreenViewController {
            _ = imageFullScreenViewController.view
            imageFullScreenViewController.viewModel = viewModel?.liveViewFullScreenViewModel
        }
    }

    @IBAction func browseImageGallery(_ sender: UIButton) {
        present(imagePickerController, animated: true)
    }

    @IBAction func performSearch(_ sender: UIButton) {
        viewModel?.performSearchObserver.send(value: ())
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update gradient layer based on the scroll view content offset
        var yOffset = scrollView.contentOffset.y
        yOffset = yOffset < 0 ? 0 : yOffset
        if 0...70 ~= yOffset {
            gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: yOffset)
        }
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
        viewModel?.selectedImage.value = info[.originalImage] as? UIImage
        viewModel?.performSearchObserver.send(value: ())
        picker.dismiss(animated: true)
    }
}

extension ImageSearchViewController: UINavigationControllerDelegate {

}
