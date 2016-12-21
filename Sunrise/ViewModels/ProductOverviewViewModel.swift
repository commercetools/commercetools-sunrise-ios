//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

class ProductOverviewViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let nextPageObserver: Observer<Void, NoError>
    let searchText = MutableProperty("")

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>

    let pageSize: UInt = 16
    var products: [ProductProjection]

    // MARK: - Lifecycle

    override init() {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")

        isLoading = MutableProperty(true)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        super.init()

        refreshSignal
        .observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        nextPageSignal
        .observeValues { [weak self] in
            if let productCount = self?.products.count, productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount), text: self?.searchText.value ?? "")
            }
        }

        searchText.signal
        .observeValues({ [weak self] searchText in
            self?.queryForProductProjections(offset: 0, text: searchText)
        })
    }

    func productDetailsViewModelForProductAtIndexPath(_ indexPath: IndexPath) -> ProductViewModel {
        let product = products[indexPath.row]
        return ProductViewModel(product: product)
    }

    // MARK: - Data Source

    func numberOfProductsInSection(_ section: Int) -> Int {
        return products.count
    }

    func productNameAtIndexPath(_ indexPath: IndexPath) -> String {
        return products[indexPath.row].name?.localizedString ?? ""
    }

    func productImageUrlAtIndexPath(_ indexPath: IndexPath) -> String {
        return products[indexPath.row].mainVariantWithPrice?.images?.first?.url ?? ""
    }

    func productPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let price = products[indexPath.row].mainVariantWithPrice?.independentPrice, let value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    func productOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let price = products[indexPath.row].mainVariantWithPrice?.independentPrice, let value = price.value,
        let _ = price.discounted?.value else { return "" }

        return value.description
    }

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(offset: UInt, text: String = "") {
        isLoading.value = true

        ProductProjection.search(limit: pageSize, offset: offset, lang: Locale(identifier: "en"), text: text, result: { result in
            if let products = result.model?.results, result.isSuccess {
                self.products = offset == 0 ? products : self.products + products

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))

            }
            self.isLoading.value = false
        })
    }



}
