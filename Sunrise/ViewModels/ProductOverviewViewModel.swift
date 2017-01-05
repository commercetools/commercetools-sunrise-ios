//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

/// The key used for whether the user was using online or physical store
let kStorePreference = "StorePreference"

class ProductOverviewViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let nextPageObserver: Observer<Void, NoError>
    let selectOnlineStoreObserver: Observer<Void, NoError>
    let selectMyStoreObserver: Observer<Void, NoError>
    let searchText = MutableProperty("")

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let browsingStoreName: MutableProperty<String?>
    let browsingStore: MutableProperty<Channel?>

    let pageSize: UInt = 16
    var products: [ProductProjection]

    // Dialogue texts
    let browsingOptionsTitle = NSLocalizedString("Browsing Options", comment: "Browsing Options")
    let browsingOptionsMessage = NSLocalizedString("Which store would you like to browse?", comment: "Which store would you like to browse")
    let selectOnlineStoreOption = NSLocalizedString("Select Online Store", comment: "Select Online Store")
    var selectMyStoreOption: String { return String(format: NSLocalizedString("Select %@", comment: "Select My Store"), myStore?.value?.name?.localizedString ?? "") }
    let changeMyStoreOption = NSLocalizedString("Change My Store", comment: "Change My Store")
    let cancelOption = NSLocalizedString("Cancel", comment: "Cancel")
    let onlineStoreName = NSLocalizedString("Online Store", comment: "Online Store")

    // MARK: - Lifecycle

    override init() {
        products = []

        title = NSLocalizedString("Products", comment: "POP Title")
        browsingStoreName = MutableProperty(onlineStoreName)

        isLoading = MutableProperty(true)
        browsingStore = MutableProperty(nil)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        let (selectOnlineStoreSignal, selectOnlineStoreObserver) = Signal<Void, NoError>.pipe()
        self.selectOnlineStoreObserver = selectOnlineStoreObserver

        let (selectMyStoreSignal, selectMyStoreObserver) = Signal<Void, NoError>.pipe()
        self.selectMyStoreObserver = selectMyStoreObserver

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

        searchText.signal
        .observeValues({ [weak self] searchText in
            self?.queryForProductProjections(offset: 0, text: searchText)
        })

        browsingStore <~ selectOnlineStoreSignal.map { return nil }
        browsingStore <~ selectMyStoreSignal.map { [weak self] in return self?.myStore?.value }
        browsingStore.signal.observe(on: QueueScheduler())
        .observeValues { browsingStore in
            UserDefaults.standard.set(browsingStore != nil, forKey: kStorePreference)
        }

        browsingStoreName <~ browsingStore.map { [weak self] in $0?.name?.localizedString ?? self?.onlineStoreName }

        searchText <~ browsingStore.map { _ in return "" }
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
        return products[indexPath.row].mainVariantWithPrice(for: browsingStore.value)?.images?.first?.url ?? ""
    }

    func productPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].mainVariantWithPrice(for: browsingStore.value),
              let price = browsingStore.value == nil ? variant.independentPrice : variant.price(for: browsingStore.value!),
              let value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    func productOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].mainVariantWithPrice(for: browsingStore.value),
              let price = browsingStore.value == nil ? variant.independentPrice : variant.price(for: browsingStore.value!),
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
        if let myStoreId = browsingStore.value?.id {
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
