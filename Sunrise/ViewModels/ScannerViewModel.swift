//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveCocoa
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

        scannedCode.signal.observeNext { [weak self] sku in
            if sku.characters.count > 0 {
                self?.searchForProduct(sku)
            }
        }
    }

    private func searchForProduct(sku: String) {
        isLoading.value = true
        isCapturing.value = false

        Commercetools.ProductProjection.search(filter: "variants.sku:\"\(sku)\"", limit: 1, result: { result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
            product = Mapper<ProductProjection>().mapArray(results)?.first where result.isSuccess {
                self.scannedProduct.value = product

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                self.isCapturing.value = true

            } else {
                super.alertMessageObserver.sendNext(NSLocalizedString("Scanned product could not be found.", comment: "Scanned product not found"))
                self.isCapturing.value = true

            }
            self.isLoading.value = false
        })
    }

}