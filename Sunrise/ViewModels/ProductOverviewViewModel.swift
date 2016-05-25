//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class ProductOverviewViewModel {

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let alertMessageSignal: Signal<String, NoError>

    private let alertMessageObserver: Observer<String, NoError>
    private var products: [ProductProjection]

    // MARK: Lifecycle

    // After implementing POP search, view model will be instantiated with initial query
    init(limit: UInt) {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")

        self.isLoading = MutableProperty(true)

        let (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        self.alertMessageSignal = alertMessageSignal
        self.alertMessageObserver = alertMessageObserver

        // After implementing POP search, view model will be instantiated with initial query
        Commercetools.ProductProjection.query(limit: limit, result: { [weak self] result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
                    products = Mapper<ProductProjection>().mapArray(results) where result.isSuccess {
                self?.products = products
                self?.isLoading.value = false

            } else if let errors = result.errors where result.isFailure {
                let alertMessage = errors.map({
                    var alertMessage = ""
                    if let failureReason = $0.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                        alertMessage += failureReason
                    }
                    if let localizedDescription = $0.userInfo[NSLocalizedDescriptionKey] as? String {
                        alertMessage += ": \(localizedDescription)"
                    }
                    return alertMessage
                }).joinWithSeparator("\n")
                alertMessageObserver.sendNext(alertMessage)
            }
        })
    }

    func productDetailsViewModelForProductAtIndexPath(indexPath: NSIndexPath) -> ProductViewModel {
        let product = products[indexPath.row]
        return ProductViewModel(product: product)
    }

    // MARK: - Data Source

    func numberOfProductsInSection(section: Int) -> Int {
        return products.count
    }

    func productNameAtIndexPath(indexPath: NSIndexPath) -> String {
        return products[indexPath.row].name?.localizedString ?? ""
    }

    func productImageUrlAtIndexPath(indexPath: NSIndexPath) -> String {
        return products[indexPath.row].mainVariantWithPrice?.images?.first?.url ?? ""
    }

    func productPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = products[indexPath.row].mainVariantWithPrice?.independentPrice, value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return "\(discounted)"
        } else {
            return "\(value)"
        }
    }

    func productOldPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = products[indexPath.row].mainVariantWithPrice?.independentPrice, value = price.value,
        _ = price.discounted?.value else { return "" }

        return "\(value)"
    }

}