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
    let willAppearObserver: Observer<Void, NoError>
    let searchText = MutableProperty("")

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let browsingStoreName: MutableProperty<String?>

    let pageSize: UInt = 16
    var products: [ProductProjection]
    var didBindMyStore = false
    private let onlineStoreName = NSLocalizedString("Online Store", comment: "Online Store")

    // MARK: - Lifecycle

    override init() {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")
        browsingStoreName = MutableProperty(onlineStoreName)

        isLoading = MutableProperty(true)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        let (willAppearSignal, willAppearObserver) = Signal<Void, NoError>.pipe()
        self.willAppearObserver = willAppearObserver

        super.init()

        // Querying for product projections needs to done only when the profile / account info is not loading
        // (the results depend on if and which store is selected)
        if let accountInfoIsLoading = AppRouting.accountViewController?.viewModel?.isLoading {
            refreshSignal.combineLatest(with: accountInfoIsLoading.signal)
            .observeValues { [weak self] _, accountInfoIsLoading in
                self?.isLoading.value = true
                if !accountInfoIsLoading {
                    self?.queryForProductProjections(offset: 0)
                }
            }
        } else {
            refreshSignal
            .observeValues { [weak self] in
                self?.queryForProductProjections(offset: 0)
            }
        }

        nextPageSignal
        .observeValues { [weak self] in
            if let productCount = self?.products.count, productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount), text: self?.searchText.value ?? "")
            }
        }

        willAppearSignal
        .observeValues { [weak self] in
            self?.bindMyStoreProperties()
        }

        searchText.signal
        .observeValues({ [weak self] searchText in
            self?.queryForProductProjections(offset: 0, text: searchText)
        })

        bindMyStoreProperties()
    }

    func bindMyStoreProperties() {
        guard let myStore = myStore, !didBindMyStore else { return }

        browsingStoreName <~ myStore.map { [weak self] in $0?.name?.localizedString ?? self?.onlineStoreName }

        searchText <~ myStore.map { [weak self] _ in
            self?.queryForProductProjections(offset: 0)
            return ""
        }

        didBindMyStore = true
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
        guard let variant = products[indexPath.row].mainVariantWithPrice,
              let price = myStore?.value == nil ? variant.independentPrice : variant.price(for: myStore!.value!),
              let value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    func productOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].mainVariantWithPrice,
              let price = myStore?.value == nil ? variant.independentPrice : variant.price(for: myStore!.value!),
              let value = price.value, price.discounted?.value != nil else { return "" }

        return value.description
    }

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(offset: UInt, text: String = "") {
        guard AppRouting.accountViewController?.viewModel?.isLoading.value != true else { return }
        isLoading.value = true

        // Sort by newer first, but only when the user performs a text search
        var sort: [String]? = nil
        if text != "" {
            sort = ["createdAt desc"]
        }

        // When the user is browsing store inventory, include a filter, to limit POP results accordingly
        var filter: String? = nil
        if let myStoreId = myStore?.value?.id {
            filter = "variants.availability.channels.\(myStoreId).isOnStock:true"
        }

        ProductProjection.search(sort: sort, limit: pageSize, offset: offset, lang: Locale(identifier: "en"), text: text,
                                 filter: filter, result: { result in
            if let products = result.model?.results, result.isSuccess {
                self.products = offset == 0 ? products : self.products + products

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))

            }
            self.isLoading.value = false
        })
    }



}
