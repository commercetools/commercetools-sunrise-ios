//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result

class ImageFullScreenViewModel: BaseViewModel {

    // Inputs
    let capturedImage = MutableProperty<UIImage?>(nil)

    // Outputs
    let isTakePhotoButtonHidden = MutableProperty(false)
    let isSearchButtonHidden = MutableProperty(true)

    private let disposables = CompositeDisposable()

    // MARK: Lifecycle

    override init() {

        super.init()

        disposables += isTakePhotoButtonHidden <~ capturedImage.map { $0 != nil }
        disposables += isSearchButtonHidden <~ capturedImage.map { $0 == nil }

    }

    deinit {
        disposables.dispose()
    }
}