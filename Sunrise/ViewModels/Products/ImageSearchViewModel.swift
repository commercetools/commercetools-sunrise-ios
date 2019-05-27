//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Photos

class ImageSearchViewModel: NSObject {

    enum CellType {
        case liveView
        case image
    }

    // Inputs
    let dismissObserver: Signal<Void, NoError>.Observer
    let resetImageSelectionObserver: Signal<Void, NoError>.Observer
    let prefetchItemsObserver: Signal<[IndexPath], NoError>.Observer
    let cancelPrefetchingObserver: Signal<[IndexPath], NoError>.Observer
    let selectedItemIndexPath = MutableProperty<IndexPath?>(nil)
    let selectedImage = MutableProperty<UIImage?>(nil)

    // Outputs
    let reloadCollectionViewSignal: Signal<Void, NoError>
    let reloadItemsSignal: Signal<[IndexPath], NoError>
    let dismissSignal: Signal<Void, NoError>
    let shouldPresentPhotosAccessDeniedAlert = MutableProperty(false)
    let isSearchButtonHidden = MutableProperty(true)

    private let reloadCollectionViewObserver: Signal<Void, NoError>.Observer
    private var imageManager: PHCachingImageManager?
    private var fetchResult: PHFetchResult<PHAsset>?
    private let disposables = CompositeDisposable()

    private static let photosPerRow: Int = 3
    private static let leadingTrailingSpace: CGFloat = 20.0
    static let itemSpacing: CGFloat = 6.0
    static let itemSize: CGSize = {
        let availableWidthForItems = UIScreen.main.bounds.width - CGFloat(photosPerRow - 1) * itemSpacing - leadingTrailingSpace
        let itemWidth = availableWidthForItems / CGFloat(photosPerRow)
        return CGSize(width: itemWidth, height: itemWidth)
    }()

    // Dialogue texts
    static let okAction = NSLocalizedString("OK", comment: "OK")
    static let settingsAction = NSLocalizedString("Settings", comment: "Settings")
    static let photosAccessDeniedTitle = NSLocalizedString("Cannot access photos", comment: "Cannot access photos")
    static let photosAccessDeniedMessage = NSLocalizedString("Please enable access to photos for Sunrise app", comment: "Photos permission prompt")

    // MARK: Lifecycle

    override init() {
        (reloadCollectionViewSignal, reloadCollectionViewObserver) = Signal<Void, NoError>.pipe()
        (dismissSignal, dismissObserver) = Signal<Void, NoError>.pipe()

        let (resetImageSelectionSignal, resetImageSelectionObserver) = Signal<Void, NoError>.pipe()
        self.resetImageSelectionObserver = resetImageSelectionObserver

        let (prefetchItemsSignal, prefetchItemsObserver) = Signal<[IndexPath], NoError>.pipe()
        self.prefetchItemsObserver = prefetchItemsObserver

        let (cancelPrefetchingSignal, cancelPrefetchingObserver) = Signal<[IndexPath], NoError>.pipe()
        self.cancelPrefetchingObserver = cancelPrefetchingObserver

        let (reloadItemsSignal, reloadItemsObserver) = Signal<[IndexPath], NoError>.pipe()
        self.reloadItemsSignal = reloadItemsSignal

        super.init()

        disposables += prefetchItemsSignal.observeValues { [weak self] indexPaths in
            guard let fetchResult = self?.fetchResult else { return }
            let assets = indexPaths.map { fetchResult.object(at: $0.item) }
            self?.imageManager?.startCachingImages(for: assets, targetSize: ProfilePhotoViewModel.itemSize, contentMode: .aspectFill, options: nil)
        }

        disposables += cancelPrefetchingSignal.observeValues { [weak self] indexPaths in
            guard let fetchResult = self?.fetchResult else { return }
            let assets = indexPaths.map { fetchResult.object(at: $0.item) }
            self?.imageManager?.stopCachingImages(for: assets, targetSize: ProfilePhotoViewModel.itemSize, contentMode: .aspectFill, options: nil)
        }

        disposables += resetImageSelectionSignal.observeValues { [weak self] in
            self?.reloadCollectionViewObserver.send(value: ())
        }

        disposables += selectedItemIndexPath.signal
        .combinePrevious()
        .skipRepeats { $0 == $1 }
        .observeValues { [weak self] in
            if let current = $1, $0 == $1 {
                DispatchQueue.main.async {
                    self?.selectedItemIndexPath.value = nil
                    reloadItemsObserver.send(value: [current])
                }
            } else {
                var indexPathsToReload = [IndexPath]()
                if let previous = $0 {
                    indexPathsToReload.append(previous)
                }
                if let current = $1 {
                    indexPathsToReload.append(current)
                }
                reloadItemsObserver.send(value: indexPathsToReload)
            }
        }

        disposables += selectedItemIndexPath <~ resetImageSelectionSignal.map { nil }
        disposables += isSearchButtonHidden <~ selectedItemIndexPath.map { $0 == nil || $0 == IndexPath(item: 0, section: 0) }

        PHPhotoLibrary.shared().register(self)

        switch PHPhotoLibrary.authorizationStatus() {
            case .authorized:
                reloadPhotos()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { [weak self] status in
                    guard status == .authorized else {
                        self?.shouldPresentPhotosAccessDeniedAlert.value = true
                        return
                    }
                    self?.reloadPhotos()
                }
            default:
                shouldPresentPhotosAccessDeniedAlert.value = true
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        disposables.dispose()
    }

    // MARK: - Data Source

    var numberOfItems: Int {
        return (fetchResult?.count ?? 0) + 1
    }

    func cellType(at indexPath: IndexPath) -> CellType {
        return indexPath.item == 0 ? .liveView : .image
    }

    func image(at indexPath: IndexPath, completion: @escaping (UIImage?) -> Void) {
        guard let fetchResult = fetchResult else {
            completion(nil)
            return
        }
        let phAsset = fetchResult.object(at: indexPath.row - 1)
        imageManager?.requestImage(for: phAsset, targetSize: ProfilePhotoViewModel.itemSize, contentMode: .aspectFill, options: nil) { (image, _) in
            completion(image)
        }
    }

    func isSelectedIndicatorHidden(at indexPath: IndexPath) -> Bool {
        return indexPath != selectedItemIndexPath.value
    }

    // MARK: - Loading photos from the library

    private func reloadPhotos() {
        DispatchQueue.global().async { [weak self] in
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            DispatchQueue.main.async {
                self?.imageManager = self?.imageManager ?? PHCachingImageManager()
                self?.fetchResult = results
                self?.reloadCollectionViewObserver.send(value: ())
            }
        }
    }
}

extension ImageSearchViewModel: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        reloadPhotos()
    }
}
