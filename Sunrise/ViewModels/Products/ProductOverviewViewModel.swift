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
    let toggleWishListObserver: Signal<IndexPath, NoError>.Observer
    let textSearch = MutableProperty(("", Locale.current))
    let userLocation: MutableProperty<CLLocation?> = MutableProperty(nil)

    // Outputs
    let isLoading: MutableProperty<Bool>
    let presentProductDetailsSignal: Signal<ProductDetailsViewModel, NoError>
    let scrollToBeginningSignal: Signal<Void, NoError>

    let category: MutableProperty<Category?> = MutableProperty(nil)
    let pageSize: UInt = 16

    var filtersViewModel: FiltersViewModel? {
        didSet {
            bindFiltersViewModel()
        }
    }
    private var products: [ProductProjection]
    private let presentProductDetailsObserver: Signal<ProductDetailsViewModel, NoError>.Observer
    private let scrollToBeginningObserver: Signal<Void, NoError>.Observer

    private let geocoder = CLGeocoder()
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        products = []

        isLoading = MutableProperty(true)
        (presentProductDetailsSignal, presentProductDetailsObserver) = Signal<ProductDetailsViewModel, NoError>.pipe()
        (scrollToBeginningSignal, scrollToBeginningObserver) = Signal<Void, NoError>.pipe()

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (nextPageSignal, pageObserver) = Signal<Void, NoError>.pipe()
        nextPageObserver = pageObserver

        let (clearProductsSignal, clearProductsObserver) = Signal<Void, NoError>.pipe()
        self.clearProductsObserver = clearProductsObserver

        let (toggleWishListSignal, toggleWishListObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver

        super.init()

        disposables += refreshSignal
        .observe(on: QueueScheduler(qos: .userInitiated))
        .observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += category.producer
        .filter { $0 != nil }
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

        disposables += clearProductsSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.products = []
            self?.isLoading.value = false
        }

        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            let product = self.products[$0.item]
            self.disposables += AppRouting.wishListViewController?.viewModel?.toggleWishListAction.apply((product.id, product.displayVariant()?.id))
            .startWithCompleted { [unowned self] in
                self.isLoading.value = false
            }
        }

        disposables += textSearch.producer
        .skipRepeats { $0.0 == $1.0 && $0.1 == $1.1 }
        .filter { $0.0 != "" }
        .observe(on: QueueScheduler(qos: .userInitiated))
        .startWithValues { [weak self] previous, current in
            self?.queryForProductProjections(offset: 0)
        }

        AppDelegate.currentCurrency = Locale.current.currencyCode
        AppDelegate.currentCountry = (Locale.current as NSLocale).countryCode
        disposables += userLocation.producer
        .observe(on: QueueScheduler(qos: .userInteractive))
        .startWithValues { [weak self] location in
            guard let location = location else { return }
            self?.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let isoCountryCode = placemarks?.first?.isoCountryCode else { return }
                    AppDelegate.currentCountry = isoCountryCode
                    AppDelegate.currentCurrency = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.countryCode.rawValue: isoCountryCode])).currencyCode
                    // Update price slider price formatting
                    self?.filtersViewModel?.priceRange.value = self?.filtersViewModel?.priceRange.value ?? (FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax)
                    // Refresh products if needed
                    if self?.products.count ?? 0 > 0 {
                        self?.queryForProductProjections(offset: 0)
                    }
                }
            }
        }
    }

    func bindFiltersViewModel() {
        guard let viewModel = filtersViewModel else { return }

        disposables += viewModel.activeBrands.producer
        .skipRepeats()
        .filter { [unowned self] _ in self.filtersViewModel?.isActive.value == true }
        .startWithValues { [weak self] _ in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += viewModel.activeSizes.producer
        .skipRepeats()
        .filter { [unowned self] _ in self.filtersViewModel?.isActive.value == true }
        .startWithValues { [weak self] _ in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += viewModel.activeColors.producer
        .skipRepeats()
        .filter { [unowned self] _ in self.filtersViewModel?.isActive.value == true }
        .startWithValues { [weak self] _ in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += viewModel.priceSetSignal?.observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += viewModel.resetFiltersAction.values.observeValues { [weak self] in
            self?.queryForProductProjections(offset: 0)
        }
    }

    deinit {
        disposables.dispose()
    }

    func productDetailsViewModelForProduct(at indexPath: IndexPath) -> ProductDetailsViewModel {
        let product = products[indexPath.row]
        let variant = products[indexPath.row].displayVariant()
        let viewModel = ProductDetailsViewModel(product: product, variantId: variant?.id, productsViewModel: self)
        return viewModel
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

    // MARK: - Commercetools product projections querying

    private func queryForProductProjections(offset: UInt) {
        let text = textSearch.value.0
        let locale = textSearch.value.1
        isLoading.value = true

        var filters = [String]()
        var filterQuery = [String]()
        var facets = [String]()

        if let categoryId = category.value?.id {
            filterQuery.append("categories.id:subtree(\"\(categoryId)\")")
        }
        if let mainProductTypeId = filtersViewModel?.mainProductType?.id {
            filterQuery.append("productType.id:\"\(mainProductTypeId)\"")
        }
        if let lower = filtersViewModel?.priceRange.value.0, let upper = filtersViewModel?.priceRange.value.1, AppDelegate.currentCurrency != nil {
            filterQuery.append("variants.price.centAmount:range (\(lower * 100) to \(upper == FiltersViewModel.kPriceMax ? "*" : (upper * 100).description))")
        }

        [(FiltersViewModel.kBrandAttributeName, filtersViewModel?.activeBrands.value),
         (FiltersViewModel.kSizeAttributeName, filtersViewModel?.activeSizes.value),
         (FiltersViewModel.kColorsAttributeName, filtersViewModel?.activeColors.value)].forEach {
            if let activeValues = $1, activeValues.count > 0 {
                var filterValue = activeValues.reduce("", { "\($0),\"\($1)\"" })
                filterValue.removeFirst()
                filters.append("variants.attributes.\($0).key:\(filterValue)")
            }

            facets.append("variants.attributes.\($0).key")
        }

        ProductProjection.search(limit: pageSize, offset: offset, lang: locale, text: text,
                                 filters: filters, filterQuery: filterQuery, facets: facets, result: { result in
            DispatchQueue.main.async {
                if let products = result.model?.results, text == self.textSearch.value.0, locale == self.textSearch.value.1, result.isSuccess {
                    if offset == 0 && products.count > 0 && self.products.count > 0 {
                        self.scrollToBeginningObserver.send(value: ())
                    }
                    self.products = offset == 0 ? products : self.products + products
                    self.filtersViewModel?.facets.value = result.model?.facets

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))

                }
                self.isLoading.value = false
            }
        })
    }

    // MARK: - Presenting product details from the universal links

    func presentProductDetails(for sku: String) {
        isLoading.value = true
        ProductProjection.search(filters: ["variants.sku:\"\(sku)\""]) { result in
            if let product = result.model?.results.first, result.isSuccess {
                self.presentProductDetailsObserver.send(value: ProductDetailsViewModel(product: product))

            } else if result.model?.count == 0 {
                super.alertMessageObserver.send(value: NSLocalizedString("The product could not be found", comment: "Product not found"))

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }
}