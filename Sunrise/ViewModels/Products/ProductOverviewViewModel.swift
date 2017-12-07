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
    let refreshObserver: Signal<Void, NoError>.Observer
    let nextPageObserver: Signal<Void, NoError>.Observer
    let selectOnlineStoreObserver: Signal<Void, NoError>.Observer
    let selectMyStoreObserver: Signal<Void, NoError>.Observer
    let textSearch = MutableProperty(("", Locale.current))

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let browsingStoreName: MutableProperty<String?>
    let browsingStore: MutableProperty<Channel?>
    let presentProductDetailsSignal: Signal<ProductViewModel, NoError>
    let scrollToBeginningSignal: Signal<Void, NoError>

    let pageSize: UInt = 16
    var products: [ProductProjection]
    private let presentProductDetailsObserver: Signal<ProductViewModel, NoError>.Observer
    private let scrollToBeginningObserver: Signal<Void, NoError>.Observer
    private var category: Category?
    private let disposables = CompositeDisposable()

    // Dialogue texts
    let browsingOptionsTitle = NSLocalizedString("Browsing Options", comment: "Browsing Options")
    let browsingOptionsMessage = NSLocalizedString("Which store would you like to browse?", comment: "Which store would you like to browse")
    let selectOnlineStoreOption = NSLocalizedString("Select Online Store", comment: "Select Online Store")
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
        (scrollToBeginningSignal, scrollToBeginningObserver) = Signal<Void, NoError>.pipe()

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        let (selectOnlineStoreSignal, selectOnlineStoreObserver) = Signal<Void, NoError>.pipe()
        self.selectOnlineStoreObserver = selectOnlineStoreObserver

        let (selectMyStoreSignal, selectMyStoreObserver) = Signal<Void, NoError>.pipe()
        self.selectMyStoreObserver = selectMyStoreObserver

        super.init()

        disposables += refreshSignal
        .observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += nextPageSignal
        .observeValues { [weak self] in
            if let productCount = self?.products.count, productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount))
            }
        }

        disposables += textSearch.combinePrevious(textSearch.value).signal
        .observeValues({ [weak self] previous, current in
            guard previous != current else { return }
            self?.queryForProductProjections(offset: 0)
        })

        browsingStoreName <~ browsingStore.map { [weak self] in $0?.name?.localizedString ?? self?.onlineStoreName }

        textSearch <~ browsingStore.map { _ in return ("", Locale.current) }
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
        return products[indexPath.row].name.localizedString ?? ""
    }

    func productImageUrlAtIndexPath(_ indexPath: IndexPath) -> String {
        return products[indexPath.row].mainVariantWithPrice(for: browsingStore.value)?.images?.first?.url ?? ""
    }

    func productPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].mainVariantWithPrice(for: browsingStore.value),
              let price = browsingStore.value == nil ? variant.independentPrice : variant.price(for: browsingStore.value!) else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }

    func productOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].mainVariantWithPrice(for: browsingStore.value),
              let price = browsingStore.value == nil ? variant.independentPrice : variant.price(for: browsingStore.value!),
              price.discounted?.value != nil else { return "" }

        return price.value.description
    }

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(offset: UInt) {
        let text = textSearch.value.0
        let locale = textSearch.value.1
        isLoading.value = true

        // When the user is browsing store inventory, include a filter, to limit POP results accordingly
        var filters = [String]()
        if let myStoreId = browsingStore.value?.id {
            filters.append("variants.availability.channels.\(myStoreId).isOnStock:true")
        }
        // If the POP is being presented from the categories selection screen, filter by the category ID
        if let categoryId = category?.id {
            filters.append("categories.id:subtree(\"\(categoryId)\")")
        }

        ProductProjection.search(limit: pageSize, offset: offset, lang: locale, text: text,
                                 filters: filters, result: { result in
            if let products = result.model?.results, text == self.textSearch.value.0, locale == self.textSearch.value.1, result.isSuccess {
                if offset == 0 && products.count > 0 && self.products.count > 0 {
                    self.scrollToBeginningObserver.send(value: ())
                }
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
            if let product = result.model?.results.first, result.isSuccess {
                self.presentProductDetailsObserver.send(value: ProductViewModel(product: product))

            } else if result.model?.count == 0 {
                super.alertMessageObserver.send(value: NSLocalizedString("The product could not be found", comment: "Product not found"))

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }
}
