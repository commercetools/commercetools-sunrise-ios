//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift

class ScannerViewModel: BaseViewModel {

    // Inputs
    let scannedCode = MutableProperty("")

    // Outputs
    let scannedProduct: MutableProperty<ProductProjection?>
    let isLoading = MutableProperty(false)
    let isCapturing = MutableProperty(false)

    private let disposables = CompositeDisposable()

    // MARK: Lifecycle

    override init() {
        scannedProduct = MutableProperty(nil)

        super.init()

        disposables += scannedCode.signal.observeValues { [weak self] sku in
            if sku.count > 0 {
                self?.searchForProduct(sku)
            }
        }
    }

    deinit {
        disposables.dispose()
    }

    private func searchForProduct(_ sku: String) {
        isLoading.value = true
        isCapturing.value = false

        ProductProjection.search(limit: 1, filters: ["variants.sku:\"\(sku)\""], markMatchingVariants: true, result: { result in
            if let product = result.model?.results.first, result.isSuccess {
                self.scannedProduct.value = product

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isCapturing.value = true

            } else {
                super.alertMessageObserver.send(value: NSLocalizedString("Scanned product could not be found.", comment: "Scanned product not found"))
                self.isCapturing.value = true

            }
            self.isLoading.value = false
        })
    }
}