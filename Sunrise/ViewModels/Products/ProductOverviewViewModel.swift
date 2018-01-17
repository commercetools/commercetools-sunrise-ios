//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import CoreLocation
import ReactiveSwift
import Result
import Commercetools

class ProductOverviewViewModel: BaseViewModel {

    typealias Category = Commercetools.Category

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let nextPageObserver: Signal<Void, NoError>.Observer
    let clearProductsObserver: Signal<Void, NoError>.Observer
    let textSearch = MutableProperty(("", Locale.current))
    let userLocation: MutableProperty<CLLocation?> = MutableProperty(nil)

    // Outputs
    let isLoading: MutableProperty<Bool>
    let presentProductDetailsSignal: Signal<ProductViewModel, NoError>
    let scrollToBeginningSignal: Signal<Void, NoError>

    let category: MutableProperty<Category?> = MutableProperty(nil)
    let pageSize: UInt = 16

    private var products: [ProductProjection]
    private let presentProductDetailsObserver: Signal<ProductViewModel, NoError>.Observer
    private let scrollToBeginningObserver: Signal<Void, NoError>.Observer

    private let geocoder = CLGeocoder()
    private var currentCountry: String?
    private var currentCurrency: String?
    private var customerGroup: Reference<CustomerGroup>?
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        products = []

        isLoading = MutableProperty(true)
        (presentProductDetailsSignal, presentProductDetailsObserver) = Signal<ProductViewModel, NoError>.pipe()
        (scrollToBeginningSignal, scrollToBeginningObserver) = Signal<Void, NoError>.pipe()

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        let (clearProductsSignal, clearProductsObserver) = Signal<Void, NoError>.pipe()
        self.clearProductsObserver = clearProductsObserver

        super.init()

        disposables += refreshSignal
        .observe(on: QueueScheduler(qos: .userInitiated))
        .observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += category.producer
        .observe(on: QueueScheduler(qos: .userInitiated))
        .startWithValues { [weak self] _ in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += nextPageSignal
        .observe(on: QueueScheduler(qos: .userInitiated))
        .observeValues { [weak self] in
            if let productCount = self?.products.count, productCount > 0 {
                self?.queryForProductProjections(offset: UInt(productCount))
            }
        }

        disposables += NotificationCenter.default.reactive.notifications(forName: Foundation.Notification.Name.Navigation.resetSearch)
        .delay(0.8, on: QueueScheduler())
        .observeValues { [weak self] _ in
            self?.textSearch.value.0 = ""
            self?.category.value = nil
        }

        disposables += clearProductsSignal.observeValues { [weak self] in
            self?.products = []
            self?.isLoading.value = false
        }

        disposables += textSearch.combinePrevious(textSearch.value).signal
        .observe(on: QueueScheduler(qos: .userInitiated))
        .observeValues({ [weak self] previous, current in
            self?.queryForProductProjections(offset: 0)
        })

        disposables += userLocation.producer
        .observe(on: QueueScheduler(qos: .userInteractive))
        .startWithValues { [weak self] location in
            guard let location = location else {
                self?.currentCountry = nil
                self?.currentCurrency = nil
                return
            }
            self?.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let isoCountryCode = placemarks?.first?.isoCountryCode else { return }
                    self?.currentCountry = isoCountryCode
                    self?.currentCurrency = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.countryCode.rawValue: isoCountryCode])).currencyCode
                    self?.queryForProductProjections(offset: 0)
                }
            }
        }
    }

    deinit {
        disposables.dispose()
    }

    func productDetailsViewModelForProduct(at indexPath: IndexPath) -> ProductViewModel {
        let product = products[indexPath.row]
        return ProductViewModel(product: product)
    }

    // MARK: - Data Source

    func numberOfProducts(in section: Int) -> Int {
        return products.count
    }

    func productName(at indexPath: IndexPath) -> String {
        return products[indexPath.row].name.localizedString ?? ""
    }

    func productImageUrl(at indexPath: IndexPath) -> String {
        return products[indexPath.row].displayVariant(country: currentCountry, currency: currentCurrency, customerGroup: customerGroup)?.images?.first?.url ?? ""
    }

    func productPrice(at indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].displayVariant(country: currentCountry, currency: currentCurrency, customerGroup: customerGroup),
              let price = variant.independentPrice else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }

    func productOldPrice(at indexPath: IndexPath) -> String {
        guard let variant = products[indexPath.row].displayVariant(country: currentCountry, currency: currentCurrency, customerGroup: customerGroup),
              let price = variant.price(country: currentCountry, currency: currentCurrency, customerGroup: customerGroup),
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
        // If the POP is being presented from the categories selection screen, filter by the category ID
        if let categoryId = category.value?.id {
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
