//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result
import Commercetools

class InlineProductOverviewViewModel: BaseViewModel {
    
    // Inputs
    let toggleWishListObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let title: String
    let isLoading = MutableProperty(false)

    private var products: [ProductProjection]
    private let filterQuery: [String]
    private let disposables = CompositeDisposable()
    
    
    // MARK: - Lifecycle
    
    init(title: String, filterQuery: [String]) {
        products = []
        self.title = title
        self.filterQuery = filterQuery

        let (toggleWishListSignal, toggleWishListObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver
        
        super.init()

        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            let product = self.products[$0.item]
            self.disposables += AppRouting.wishListViewController?.viewModel?.toggleWishListAction.apply((product.id, product.displayVariant()?.id))
            .startWithCompleted { [unowned self] in
                self.isLoading.value = false
            }
        }

        queryForProductProjections(filterQuery: filterQuery)
    }
    
    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    func numberOfProducts(in section: Int) -> Int {
        return products.count
    }

    func productName(at indexPath: IndexPath) -> String {
        return products[indexPath.row].name.localizedString ?? ""
    }

    func productImageUrl(at indexPath: IndexPath) -> String {
        return products[indexPath.row].displayVariant()?.images?.first?.url ?? ""
    }

    func productPrice(at indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].displayVariant(),
              let price = variant.price() else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }

    func productOldPrice(at indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].displayVariant(),
              let price = variant.price(),
              price.discounted?.value != nil else { return "" }

        return price.value.description
    }

    func isProductInWishList(at indexPath: IndexPath) -> Bool {
        let product = products[indexPath.row]
        return AppRouting.wishListViewController?.viewModel?.lineItems.value.contains { $0.productId == product.id && $0.variantId == product.displayVariant()?.id} == true
    }

    func sku(at indexPath: IndexPath) -> String? {
        return products[indexPath.row].displayVariant()?.sku
    }

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(filterQuery: [String]) {
        isLoading.value = true

        ProductProjection.search(limit: 10, filterQuery: filterQuery, result: { result in
            DispatchQueue.main.async {
                if let products = result.model?.results, result.isSuccess {
                    self.products = products

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))

                }
                self.isLoading.value = false
            }
        })
    }
}

