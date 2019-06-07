//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import Photos
import AWSS3

class ProfilePhotoViewModel: NSObject {
    
    // Inputs
    let prefetchItemsObserver: Signal<[IndexPath], NoError>.Observer
    let cancelPrefetchingObserver: Signal<[IndexPath], NoError>.Observer
    let didSelectItemObserver: Signal<IndexPath, NoError>.Observer
    let doneObserver: Signal<(offset: CGPoint, scale: CGFloat), NoError>.Observer
    
    // Outputs
    let reloadCollectionViewSignal: Signal<Void, NoError>
    let performBackSegueSignal: Signal<Void, NoError>
    let alertMessageSignal: Signal<String, NoError>
    let shouldPresentPhotosAccessDeniedAlert = MutableProperty(false)
    let isLoadingFullImage = MutableProperty(false)
    let isLoading = MutableProperty(false)
    let fullImage = MutableProperty<UIImage?>(#imageLiteral(resourceName: "default-profile-photo"))
    let imageViewWidth = MutableProperty<CGFloat>(0.0)
    
    private let performBackSegueObserver: Signal<Void, NoError>.Observer
    private let reloadCollectionViewObserver: Signal<Void, NoError>.Observer
    private let alertMessageObserver: Signal<String, NoError>.Observer
    private let scaledImageWidth = MutableProperty<CGFloat>(0.0)
    private var imageManager: PHCachingImageManager?
    private var fetchResult: PHFetchResult<PHAsset>?
    private var fullImageRequestID: PHImageRequestID?
    private let transferUtility = AWSS3TransferUtility.default()
    private let disposables = CompositeDisposable()
    
    private static let photosPerRow: Int = 4
    static let itemSpacing: CGFloat = 2.0
    static let itemSize: CGSize = {
        let availableWidthForItems = UIScreen.main.bounds.width - CGFloat(photosPerRow + 1) * itemSpacing
        let itemWidth = availableWidthForItems / CGFloat(photosPerRow)
        return CGSize(width: itemWidth, height: itemWidth)
    }()
    
    // Dialogue texts
    let oopsTitle = NSLocalizedString("Oops!", comment: "Oops!")
    let okAction = NSLocalizedString("OK", comment: "OK")
    
    // MARK: - Lifecycle
    
    override init() {
        (reloadCollectionViewSignal, reloadCollectionViewObserver) = Signal<Void, NoError>.pipe()
        
        let (prefetchItemsSignal, prefetchItemsObserver) = Signal<[IndexPath], NoError>.pipe()
        self.prefetchItemsObserver = prefetchItemsObserver
        
        let (cancelPrefetchingSignal, cancelPrefetchingObserver) = Signal<[IndexPath], NoError>.pipe()
        self.cancelPrefetchingObserver = cancelPrefetchingObserver
        
        let (didSelectItemSignal, didSelectItemObserver) = Signal<IndexPath, NoError>.pipe()
        self.didSelectItemObserver = didSelectItemObserver
        
        let (doneSignal, doneObserver) = Signal<(offset: CGPoint, scale: CGFloat), NoError>.pipe()
        self.doneObserver = doneObserver
        
        (performBackSegueSignal, performBackSegueObserver) = Signal<Void, NoError>.pipe()
        
        (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        
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
        
        disposables += didSelectItemSignal.observeValues { [weak self] indexPath in
            guard let fetchResult = self?.fetchResult,
                let imageManager = self?.imageManager else { return }
            
            if let requestId = self?.fullImageRequestID {
                imageManager.cancelImageRequest(requestId)
            }
            
            self?.isLoadingFullImage.value = true
            self?.fullImage.value = nil
            let asset = fetchResult.object(at: indexPath.row)
            let assetWidth = CGFloat(asset.pixelWidth) / UIScreen.main.scale
            let assetHeight = CGFloat(asset.pixelHeight) / UIScreen.main.scale
            let size = CGSize(width: assetWidth, height: assetHeight)
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: options, resultHandler: { (image, _) in
                self?.fullImage.value = image
                self?.isLoadingFullImage.value = false
            })
        }
        
        disposables += doneSignal.observe(on: UIScheduler())
        .observeValues { [weak self] offset, scale in
            guard let image = self?.fullImage.value,
                let width = self?.scaledImageWidth.value,
                let imageViewWidth = self?.imageViewWidth.value else { return }
            
            let xScale = scale * width / image.size.width
            let yScale = scale * UIScreen.main.bounds.width / image.size.height
            let transformedWidth = UIScreen.main.bounds.width / xScale
            let transformedHeight = UIScreen.main.bounds.width / yScale
            let transformedOffset = CGPoint(x: imageViewWidth > width ? (offset.x / scale - (imageViewWidth - width) / 2) / (width / image.size.width) : offset.x / xScale, y: offset.y / yScale)
            UIGraphicsBeginImageContextWithOptions(CGSize(width: transformedWidth, height: transformedHeight), false, UIScreen.main.scale)
            image.draw(in: CGRect(x: -transformedOffset.x, y: -transformedOffset.y, width: image.size.width, height: image.size.height))
            let transformedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            self?.upload(image: transformedImage)
        }
        
        disposables += scaledImageWidth <~ fullImage.map {
            guard let image = $0 else { return 0 }
            let aspectRation = image.size.width / image.size.height
            return UIScreen.main.bounds.width * aspectRation
        }
        
        disposables += imageViewWidth <~ scaledImageWidth.map {
            return $0 < UIScreen.main.bounds.width ? UIScreen.main.bounds.width : $0
        }
        
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
        
        downloadCurrentImage()
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        disposables.dispose()
    }
    
    // MARK: - Data Source
    
    var numberOfPhotos: Int {
        return fetchResult?.count ?? 0
    }
    
    func smallImage(at indexPath: IndexPath, completion: @escaping (UIImage?) -> Void) {
        guard let fetchResult = fetchResult else {
            completion(nil)
            return
        }
        let phAsset = fetchResult.object(at: indexPath.row)
        imageManager?.requestImage(for: phAsset, targetSize: ProfilePhotoViewModel.itemSize, contentMode: .aspectFill, options: nil) { (image, _) in
            completion(image)
        }
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
    
    // MARK: - Uploading and downloading to / from an S3 bucket
    
    private func upload(image: UIImage?) {
        guard let image = image, let data = image.pngData() else { return }
        isLoading.value = true
        Customer.profile { result in
            if let errors = result.errors as? [CTError], result.isFailure {
                self.alertMessageObserver.send(value: errors.map({ $0.errorDescription ?? "" }).joined(separator: "\n"))
                self.isLoading.value = false
            } else if let customerId = result.model?.id {
                let expression = AWSS3TransferUtilityUploadExpression()
                expression.setValue("public-read", forRequestHeader: "x-amz-acl")
                self.transferUtility.uploadData(data, bucket: "commercetools-sunrise", key: "customers/profile-photos/\(customerId).png", contentType: "image/png", expression: expression, completionHandler: { _, error in
                    if let error = error {
                        self.alertMessageObserver.send(value: "\(error)")
                    } else {
                        AppRouting.profileViewController?.viewModel?.profilePhoto.value = image
                        self.performBackSegueObserver.send(value: ())
                    }
                    self.isLoading.value = false
                }).continueWith { task in
                    if let error = task.error {
                        self.alertMessageObserver.send(value: "\(error.localizedDescription)")
                    }
                    return nil
                }
            } else {
                self.isLoading.value = false
                self.performBackSegueObserver.send(value: ())
            }
        }
    }
    
    private func downloadCurrentImage() {
        isLoading.value = true
        Customer.profile { result in
            if let errors = result.errors as? [CTError], result.isFailure {
                self.alertMessageObserver.send(value: errors.map({ $0.errorDescription ?? "" }).joined(separator: "\n"))
                self.isLoading.value = false
            } else if let customerId = result.model?.id {
                self.transferUtility.downloadData(fromBucket: "commercetools-sunrise", key: "customers/profile-photos/\(customerId).png", expression: nil, completionHandler: { _, _, data, error in
                    if let data = data {
                        self.fullImage.value = UIImage(data: data)
                    }
                    if self.fullImage.value == nil || self.fullImage.value == #imageLiteral(resourceName: "default-profile-photo") && PHPhotoLibrary.authorizationStatus() == .authorized && self.numberOfPhotos > 0 {
                        self.didSelectItemObserver.send(value: IndexPath(item: 0, section: 0))
                    }
                    self.isLoading.value = false
                }).continueWith { task in return nil }
            } else {
                self.isLoading.value = false
                self.performBackSegueObserver.send(value: ())
            }
        }
    }
}

extension ProfilePhotoViewModel: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        reloadPhotos()
    }
}
