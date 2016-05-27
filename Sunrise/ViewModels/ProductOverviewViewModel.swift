//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class ProductOverviewViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let alertMessageSignal: Signal<String, NoError>

    private let alertMessageObserver: Observer<String, NoError>
    var products: [ProductProjection]

    // MARK: Lifecycle

    init() {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")

        self.isLoading = MutableProperty(false)

        let (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        self.alertMessageSignal = alertMessageSignal
        self.alertMessageObserver = alertMessageObserver

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        refreshSignal
        .observeNext { [weak self] in
            self?.queryForProductProjections()
        }
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

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections() {
        isLoading.value = true

        // After implementing POP search, view model will be instantiated with initial query
        Commercetools.ProductProjection.query(limit: 15, result: { [weak self] result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
            products = Mapper<ProductProjection>().mapArray(results) where result.isSuccess {
                self?.products = products

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
                self?.alertMessageObserver.sendNext(alertMessage)
            }
            self?.isLoading.value = false
        })
    }



}