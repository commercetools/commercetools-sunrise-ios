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
    let capturedImage = MutableProperty<UIImage?>(nil)

    // Outputs
    let reloadCollectionViewSignal: Signal<Void, NoError>
    let dismissSignal: Signal<Void, NoError>
    let captureImageSignal: Signal<Void, NoError>
    let shouldPresentPhotosAccessDeniedAlert = MutableProperty(false)
    let isSearchButtonHidden = MutableProperty(true)
    let isBrowseAllButtonHidden = MutableProperty(true)

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
    let okAction = NSLocalizedString("OK", comment: "OK")
    let settingsAction = NSLocalizedString("Settings", comment: "Settings")
    let liveViewErrorTitle = NSLocalizedString("Could not initialize live view", comment: "Image search live view error title")
    let cameraPermissionError = NSLocalizedString("In order to capture an image using live view, please go to settings and grant Camera permission.", comment: "Camera permissions error")
    let capabilitiesError = NSLocalizedString("Your device is not capable of capturing an image using live view.", comment: "Capabilities live view error")

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

        let (captureImageSignal, captureImageObserver) = Signal<Void, NoError>.pipe()
        self.captureImageSignal = captureImageSignal

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
        .filter { $0?.item == 0 }
        .observeValues { _ in
            captureImageObserver.send(value: ())
        }

        disposables += selectedItemIndexPath.signal
        .filter { $0?.item != 0 }
        .observeValues { [weak self] _ in
            self?.capturedImage.value = nil
        }

        disposables += selectedItemIndexPath <~ resetImageSelectionSignal.map { nil }
        disposables += capturedImage <~ resetImageSelectionSignal.map { nil }
        disposables += isSearchButtonHidden <~ selectedItemIndexPath.map { $0 == nil }
        disposables += isBrowseAllButtonHidden <~ selectedItemIndexPath.map { $0 != nil }

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

    func requestAuthorizations() {
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
