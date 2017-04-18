//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

/// The key used for whether the user was using online or physical store
let kStorePreference = "StorePreference"

class ProductOverviewViewModel: BaseViewModel {

    typealias Category = Commercetools.Category

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
    let presentProductDetailsSignal: Signal<ProductViewModel, NoError>

    let pageSize: UInt = 16
    var products: [ProductProjection]
    private let presentProductDetailsObserver: Observer<ProductViewModel, NoError>
    private var category: Category?
    private let disposables = CompositeDisposable()

    // Dialogue texts
    let browsingOptionsTitle = NSLocalizedString("Browsing Options", comment: "Browsing Options")
    let browsingOptionsMessage = NSLocalizedString("Which store would you like to browse?", comment: "Which store would you like to browse")
    let selectOnlineStoreOption = NSLocalizedString("Select Online Store", comment: "Select Online Store")
    var selectMyStoreOption: String { return String(format: NSLocalizedString("Select %@", comment: "Select My Store"), myStore?.value?.name?.localizedString ?? "") }
    let changeMyStoreOption = NSLocalizedString("Change My Store", comment: "Change My Store")
    let cancelOption = NSLocalizedString("Cancel", comment: "Cancel")
    let onlineStoreName = NSLocalizedString("Online Store", comment: "Online Store")

    // MARK: - Lifecycle

    init(category: Category? = nil) {
        products = []
        self.category = category

        title = NSLocalizedString("Products", comment: "POP Title")
        browsingStoreName = MutableProperty(onlineStoreName)

        isLoading = MutableProperty(true)
        browsingStore = MutableProperty(nil)
        (presentProductDetailsSignal, presentProductDetailsObserver) = Signal<ProductViewModel, NoError>.pipe()

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
            disposables += accountInfoIsLoading.combinePrevious(accountInfoIsLoading.value)
            .signal.observeValues { [weak self] previous, current in
                if previous && !current {
                    self?.queryForProductProjections(offset: 0)
                }
            }
        }

        disposables += refreshSignal
        .observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += nextPageSignal
        .observeValues { [weak self] in
            if let productCount = self?.products.count, productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount), text: self?.searchText.value ?? "")
            }
        }

        disposables += searchText.combinePrevious(searchText.value).signal
        .observeValues({ [weak self] previous, current in
            guard previous != current else { return }
            self?.queryForProductProjections(offset: 0, text: current)
        })

        browsingStore.value = UserDefaults.standard.bool(forKey: kStorePreference) ? myStore?.value : nil
        browsingStore <~ selectOnlineStoreSignal.map { return nil }
        browsingStore <~ selectMyStoreSignal.map { [weak self] in return self?.myStore?.value }
        disposables += browsingStore.combinePrevious(browsingStore.value).signal.observe(on: QueueScheduler())
        .observeValues { [weak self] previousStore, currentStore in
            guard previousStore != currentStore else { return }
            UserDefaults.standard.set(currentStore != nil, forKey: kStorePreference)
            // If set from category specific POP, update the main POP
            if let rootProductOverviewViewModel = AppRouting.productOverviewViewController?.viewModel, rootProductOverviewViewModel !== self {
                rootProductOverviewViewModel.browsingStore.value = currentStore
            } else if let categoryProductOverviewViewModel = AppRouting.categoryProductOverviewViewController?.viewModel, categoryProductOverviewViewModel !== self {
                categoryProductOverviewViewModel.browsingStore.value = currentStore
            }

            // Perform new search after the store has changed
            if self?.searchText.value == "" {
                self?.queryForProductProjections(offset: 0)
            }
        }

        browsingStoreName <~ browsingStore.map { [weak self] in $0?.name?.localizedString ?? self?.onlineStoreName }

        searchText <~ browsingStore.map { _ in return "" }
    }

    deinit {
        disposables.dispose()
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
        var filters = [String]()
        if let myStoreId = browsingStore.value?.id {
            filters.append("variants.availability.channels.\(myStoreId).isOnStock:true")
        }
        // If the POP is being presented from the categories selection screen, filter by the category ID
        if let categoryId = category?.id {
            filters.append("categories.id:subtree(\"\(categoryId)\")")
        }

        ProductProjection.search(sort: sort, limit: pageSize, offset: offset, lang: Locale(identifier: "en"), text: text,
                                 filters: filters, result: { result in
            if let products = result.model?.results, result.isSuccess {
                self.products = offset == 0 ? products : self.products + products

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))

            }
            self.isLoading.value = false
        })
    }

    // MARK: - Presenting product details from the universal links

    func presentProductDetails(for sku: String) {
        isLoading.value = true
        ProductProjection.search(filters: ["variants.sku:\"\(sku)\""]) { result in
            if let product = result.model?.results?.first, result.isSuccess {
                self.presentProductDetailsObserver.send(value: ProductViewModel(product: product))

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }
}
