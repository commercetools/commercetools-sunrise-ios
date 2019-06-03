//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result

class ImageFullScreenViewModel: BaseViewModel {

    // Inputs
    let capturedImage: MutableProperty<UIImage?>
    var performSearchObserver: Signal<Void, NoError>.Observer? {
        return imageSearchViewModel?.performSearchObserver
    }
    var presentImageSearchViewObserver: Signal<Void, NoError>.Observer? {
        return imageSearchViewModel?.presentImageSearchViewObserver
    }

    // Outputs
    let isTakePhotoButtonHidden = MutableProperty(false)
    let isSearchButtonHidden = MutableProperty(true)
    let isRemoveButtonHidden = MutableProperty(true)
    let isChooseAnotherPictureButtonHidden = MutableProperty(true)
    let dismissButtonImage: MutableProperty<UIImage>

    weak var imageSearchViewModel: ImageSearchViewModel?

    private let disposables = CompositeDisposable()

    // MARK: Lifecycle

    init(image: UIImage? = nil) {
        capturedImage = MutableProperty(image)
        dismissButtonImage = MutableProperty(image == nil ? #imageLiteral(resourceName: "live_view_close_icon") : #imageLiteral(resourceName: "live_view_back_icon"))

        super.init()

        guard image == nil else {
            [isTakePhotoButtonHidden, isSearchButtonHidden].forEach { $0.value = true }
            [isRemoveButtonHidden, isChooseAnotherPictureButtonHidden].forEach { $0.value = false }
            return
        }

        disposables += isTakePhotoButtonHidden <~ capturedImage.map { $0 != nil }
        disposables += isSearchButtonHidden <~ capturedImage.map { $0 == nil }

        disposables += capturedImage.signal
        .filter { $0 != nil }
        .observeValues { [weak self] in
            self?.imageSearchViewModel?.selectedImage.value = $0
        }
    }

    deinit {
        disposables.dispose()
    }
}