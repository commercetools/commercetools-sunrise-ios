//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD

class ProfilePhotoViewController: UIViewController {
    
    @IBOutlet weak var photosCollectionView: UICollectionView!
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var photoScrollView: UIScrollView!
    
    @IBOutlet weak var imageViewWidthConstraint: NSLayoutConstraint!
    
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: ProfilePhotoViewModel? {
        didSet {
            self.bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let collectionViewLayout = photosCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            collectionViewLayout.itemSize = ProfilePhotoViewModel.itemSize
            collectionViewLayout.minimumLineSpacing = ProfilePhotoViewModel.itemSpacing
            collectionViewLayout.minimumInteritemSpacing = ProfilePhotoViewModel.itemSpacing
        }
        viewModel = ProfilePhotoViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
        SunriseTabBarController.currentlyActive?.tabView.alpha = 0
        SunriseTabBarController.currentlyActive?.rightNavItemModel = .doneButton
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        SunriseTabBarController.currentlyActive?.tabView.alpha = 1
        SunriseTabBarController.currentlyActive?.rightNavItemModel = .cart
        super.viewWillDisappear(animated)
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }
        
        disposables += activityIndicatorView.reactive.isAnimating <~ viewModel.isLoadingFullImage
        disposables += imageView.reactive.image <~ viewModel.fullImage
        
        disposables += viewModel.imageViewWidth.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] width in
            self?.photoScrollView.zoomScale = 1.0
            self?.imageViewWidthConstraint.constant = width
            self?.photoScrollView.contentOffset = CGPoint(x: (width - UIScreen.main.bounds.width) / 2, y: 0)
        }
        
        disposables += viewModel.reloadCollectionViewSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in self?.photosCollectionView.reloadData() }
        
        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.navigationController?.popViewController(animated: true)
        }
        
        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.doneButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.viewModel?.doneObserver.send(value: (offset: self.photoScrollView.contentOffset, scale: self.photoScrollView.zoomScale))
        }
        
        disposables += viewModel.shouldPresentPhotosAccessDeniedAlert.producer
        .filter { $0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.presentPhotosAccessDeniedAlert()
        }
        
        disposables += viewModel.performBackSegueSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.navigationController?.popViewController(animated: true)
        }
        
        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues {
            if $0 {
                SVProgressHUD.show()
                UIApplication.shared.beginIgnoringInteractionEvents()
            } else {
                SVProgressHUD.dismiss()
                UIApplication.shared.endIgnoringInteractionEvents()
            }
        }
        
        disposables += viewModel.alertMessageSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] alertMessage in
            let alertController = UIAlertController(
                title: viewModel.oopsTitle,
                message: alertMessage,
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: self?.viewModel?.okAction, style: .cancel, handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }))
            self?.present(alertController, animated: true, completion: nil)
        })
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
}

extension ProfilePhotoViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        guard scrollView == scrollView else { return nil }
        return imageView
    }
}

extension ProfilePhotoViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel?.didSelectItemObserver.send(value: indexPath)
    }
}

extension ProfilePhotoViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel?.numberOfPhotos ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as? PhotoCell else { return UICollectionViewCell() }
        
        cell.imageView.image = nil
        viewModel?.smallImage(at: indexPath, completion: { image in
            let currentIndexPath = collectionView.indexPath(for: cell)
            guard currentIndexPath == nil || currentIndexPath == indexPath else { return }
            cell.imageView.image = image
        })
        
        return cell
    }
}

extension ProfilePhotoViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        viewModel?.prefetchItemsObserver.send(value: indexPaths)
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        viewModel?.cancelPrefetchingObserver.send(value: indexPaths)
    }
}
