//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift
import ObjectMapper

class ScannerViewModel: BaseViewModel {

    // Inputs
    let scannedCode = MutableProperty("")

    // Outputs
    let errorTitle = NSLocalizedString("Could not scan", comment: "Scanning error title")
    let capabilitiesError = NSLocalizedString("Your device is not capable of performing barcode scanning.", comment: "Capabilities scanning error")
    let permissionError = NSLocalizedString("In order to scan products, please go to settings and grant the Camera permission.", comment: "Camera permissions error")
    let scannedProduct: MutableProperty<ProductProjection?>
    let isLoading = MutableProperty(false)
    let isCapturing = MutableProperty(false)

    // MARK: Lifecycle

    override init() {
        scannedProduct = MutableProperty(nil)

        super.init()

        scannedCode.signal.observeValues { [weak self] sku in
            if sku.characters.count > 0 {
                self?.searchForProduct(sku)
            }
        }
    }

    private func searchForProduct(_ sku: String) {
        isLoading.value = true
        isCapturing.value = false

        Commercetools.ProductProjection.search(limit: 1, filter: "variants.sku:\"\(sku)\"", result: { result in
            if let results = result.response?["results"] as? [[String: Any]],
            let product = Mapper<ProductProjection>().mapArray(JSONArray: results)?.first, result.isSuccess {
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
