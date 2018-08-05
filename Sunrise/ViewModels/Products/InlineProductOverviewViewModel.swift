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
    let refreshObserver: Signal<Void, NoError>.Observer

    // Outputs
    let title: String
    let isLoading = MutableProperty(false)

    private let useMyStyleSettings: Bool
    private var products: [ProductProjection]
    private let disposables = CompositeDisposable()
    
    
    // MARK: - Lifecycle
    
    init(title: String, useMyStyleSettings: Bool = false, filterQuery: [String]? = nil, sort: [String]? = nil) {
        products = []
        self.title = title
        self.useMyStyleSettings = useMyStyleSettings

        let (toggleWishListSignal, toggleWishListObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        super.init()

        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            let product = self.products[$0.item]
            self.disposables += AppRouting.wishListViewController?.viewModel?.toggleWishListAction.apply((product.id, product.displayVariant()?.id))
            .startWithCompleted { [unowned self] in
                self.isLoading.value = false
            }
        }

        disposables += refreshSignal
        .observeValues { [weak self] _ in
            guard self?.useMyStyleSettings == true else { return }
            self?.queryForMyStyleProductProjections(sort: sort)
        }

        if useMyStyleSettings {
            queryForMyStyleProductProjections(sort: sort)
        } else {
            queryForProductProjections(filterQuery: filterQuery, failbackFilterQuery: [], sort: sort)
        }
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

    private func queryForMyStyleProductProjections(sort: [String]?) {
        var filterQuery = [String]()
        if Commercetools.authState == .customerToken {
            [(FiltersViewModel.kBrandAttributeName, MyStyleViewModel.brandsSettings),
             (FiltersViewModel.kSizeAttributeName, MyStyleViewModel.sizesSettings),
             (FiltersViewModel.kColorsAttributeName, MyStyleViewModel.colorsSettings)].forEach {
                if !$1.isEmpty {
                    var filterValue = $1.reduce("", { "\($0),\"\($1)\"" })
                    filterValue.removeFirst()
                    filterQuery.append("variants.attributes.\($0).key:\(filterValue)")
                }
            }
            filterQuery.append("categories.id: subtree(\"\(MyStyleViewModel.isWomenSetting ? "f8587a7d-7756-4072-8b1f-6360357218c2" : "e2191d36-21ab-4ea7-9cee-d9ff576948d1")\")")
        }
        queryForProductProjections(filterQuery: filterQuery, failbackFilterQuery: [], sort: sort)
    }

    private func queryForProductProjections(filterQuery: [String]?, failbackFilterQuery: [String]? = nil, sort: [String]?, applyFailbackFilterQuery: Bool = false) {
        isLoading.value = true

        ProductProjection.search(sort: sort, limit: 10, filterQuery: applyFailbackFilterQuery ? failbackFilterQuery : filterQuery, markMatchingVariants: true,
                                 priceCurrency: AppDelegate.currentCurrency, priceCountry: AppDelegate.currentCountry,
                                 priceCustomerGroup: AppDelegate.customerGroup?.id, result: { result in
            if let products = result.model?.results, result.isSuccess {
                if products.isEmpty && !applyFailbackFilterQuery {
                    self.queryForProductProjections(filterQuery: filterQuery, failbackFilterQuery: failbackFilterQuery, sort: sort, applyFailbackFilterQuery: true)
                    return
                }
                DispatchQueue.main.async {
                    self.products = products
                    self.isLoading.value = false
                }

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
        })
    }
}

