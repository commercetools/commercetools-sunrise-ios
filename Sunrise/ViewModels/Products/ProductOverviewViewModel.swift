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
    let clearProductsObserver: Signal<Void, NoError>.Observer
    let toggleWishListObserver: Signal<IndexPath, NoError>.Observer
    let textSearch = MutableProperty(("", Locale.current))
    let imageSearch = MutableProperty<UIImage?>(nil)
    let userLocation: MutableProperty<CLLocation?> = MutableProperty(nil)
    let additionalFilterQuery = MutableProperty([String]())
    let hasReachedLowerHalfOfProducts = MutableProperty(false)

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
    /// The default flag whether my style filters should be included.
    private var shouldIncludeMyStyleFilters = true
    /// The serial queue used for performing product projection requests.
    private let productRetrievalQueue = OperationQueue()
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

        let (clearProductsSignal, clearProductsObserver) = Signal<Void, NoError>.pipe()
        self.clearProductsObserver = clearProductsObserver

        let (toggleWishListSignal, toggleWishListObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver

        super.init()

        productRetrievalQueue.maxConcurrentOperationCount = 1
        productRetrievalQueue.qualityOfService = .userInteractive

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

        disposables += additionalFilterQuery.producer
        .filter { !$0.isEmpty }
        .observe(on: QueueScheduler(qos: .userInitiated))
        .startWithValues { [weak self] _ in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += hasReachedLowerHalfOfProducts.producer
        .observe(on: QueueScheduler(qos: .userInitiated))
        .skipRepeats()
        .filter { $0 }
        .startWithValues { [weak self] _ in
            if let productCount = self?.products.count, productCount > 0, self?.imageSearch.value == nil {
                self?.queryForProductProjections(offset: UInt(productCount))
            }
        }

        disposables += NotificationCenter.default.reactive.notifications(forName: Foundation.Notification.Name.Navigation.resetSearch)
        .observeValues { [weak self] _ in
            self?.productRetrievalQueue.isSuspended = true
            self?.imageSearch.value = nil
        }

        disposables += NotificationCenter.default.reactive.notifications(forName: Foundation.Notification.Name.Navigation.resetSearch)
        .delay(0.9, on: QueueScheduler())
        .observeValues { [weak self] _ in
            self?.textSearch.value.0 = ""
            self?.category.value = nil
            self?.additionalFilterQuery.value = []
            self?.shouldIncludeMyStyleFilters = true
            self?.productRetrievalQueue.cancelAllOperations()
            self?.productRetrievalQueue.isSuspended = false
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
        .filter { $0.0 != "" }
        .observe(on: QueueScheduler(qos: .userInitiated))
        .startWithValues { [weak self] previous, current in
            self?.queryForProductProjections(offset: 0)
        }

        disposables += imageSearch.producer
        .filter { $0 != nil }
        .observe(on: QueueScheduler(qos: .userInitiated))
        .startWithValues { [weak self] _ in
            self?.queryForImageSearchProductProjections()
        }

        Customer.currentCurrency = Locale.current.currencyCode
        Customer.currentCountry = (Locale.current as NSLocale).countryCode
        disposables += userLocation.producer
        .observe(on: QueueScheduler(qos: .userInteractive))
        .startWithValues { [weak self] location in
            guard let location = location else { return }
            self?.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                DispatchQueue.global(qos: .userInitiated).async {
                    guard let isoCountryCode = placemarks?.first?.isoCountryCode else { return }
                    Customer.currentCountry = isoCountryCode
                    Customer.currentCurrency = Locale(identifier: Locale.identifier(fromComponents: [NSLocale.Key.countryCode.rawValue: isoCountryCode])).currencyCode
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
            self?.shouldIncludeMyStyleFilters = false
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
        let includeMyStyleFilters = shouldIncludeMyStyleFilters
        productRetrievalQueue.addOperation {
            let text = self.textSearch.value.0
            let locale = self.textSearch.value.1
            self.isLoading.value = true

            var filters = [String]()
            var filterQuery = [String]()
            var facets = [String]()

            // Only include my style filters when there're no additional filters applied, and customer hasn't applied any manual filters (i.e `manuallyAppliedFilters` is false)
            if includeMyStyleFilters && self.filtersViewModel?.hasFiltersApplied == false && self.filtersViewModel?.manuallyAppliedFilters == false && self.isAuthenticated {
                self.filtersViewModel?.activeBrands.value = MyStyleViewModel.brandsSettings
                self.filtersViewModel?.activeSizes.value = MyStyleViewModel.sizesSettings
                self.filtersViewModel?.activeColors.value = MyStyleViewModel.colorsSettings

            // Reset previously applied my style filters if `includeMyStyleFilters` is false, and customer hasn't applied any manual filters (i.e `manuallyAppliedFilters` is false)
            } else if !includeMyStyleFilters && self.isAuthenticated && self.filtersViewModel?.manuallyAppliedFilters == false
                              && self.filtersViewModel?.activeBrands.value == MyStyleViewModel.brandsSettings
                              && self.filtersViewModel?.activeSizes.value == MyStyleViewModel.sizesSettings
                              && self.filtersViewModel?.activeSizes.value == MyStyleViewModel.sizesSettings {
                self.filtersViewModel?.activeBrands.value = []
                self.filtersViewModel?.activeSizes.value = []
                self.filtersViewModel?.activeColors.value = []
            }

            filterQuery += self.additionalFilterQuery.value
            if let categoryId = self.category.value?.id {
                filterQuery.append("categories.id:subtree(\"\(categoryId)\")")
            }
            if let mainProductTypeId = self.filtersViewModel?.mainProductType?.id {
                filterQuery.append("productType.id:\"\(mainProductTypeId)\"")
            }
            if let lower = self.filtersViewModel?.priceRange.value.0, let upper = self.filtersViewModel?.priceRange.value.1, Customer.currentCurrency != nil {
                filterQuery.append("variants.price.centAmount:range (\(lower * 100) to \(upper == FiltersViewModel.kPriceMax ? "*" : (upper * 100).description))")
            }

            [(FiltersViewModel.kBrandAttributeName, self.filtersViewModel?.activeBrands.value),
             (FiltersViewModel.kSizeAttributeName, self.filtersViewModel?.activeSizes.value),
             (FiltersViewModel.kColorsAttributeName, self.filtersViewModel?.activeColors.value)].forEach {
                if let activeValues = $1, activeValues.count > 0 {
                    var filterValue = activeValues.reduce("", { "\($0),\"\($1)\"" })
                    filterValue.removeFirst()
                    filters.append("variants.attributes.\($0).key:\(filterValue)")
                }

                facets.append("variants.attributes.\($0).key")
            }

            let semaphore = DispatchSemaphore(value: 0)
            ProductProjection.search(limit: self.pageSize, offset: offset, lang: locale, text: text,
                    filters: filters, filterQuery: filterQuery, facets: facets, markMatchingVariants: true,
                    priceCurrency: Customer.currentCurrency, priceCountry: Customer.currentCountry,
                    priceCustomerGroup: Customer.customerGroup?.id) { [unowned self] result in

                if let products = result.model?.results, text == self.textSearch.value.0, locale == self.textSearch.value.1, result.isSuccess {
                    // If there were no results with my style filters applied, try again without them
                    if offset == 0 && products.count == 0 && includeMyStyleFilters {
                        self.shouldIncludeMyStyleFilters = false
                        self.queryForProductProjections(offset: 0)
                        semaphore.signal()
                    }
                    DispatchQueue.main.async {
                        if offset == 0 && products.count > 0 && self.products.count > 0 {
                            self.scrollToBeginningObserver.send(value: ())
                        }
                        self.products = offset == 0 ? products : self.products + products
                        self.filtersViewModel?.facets.value = result.model?.facets
                    }

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self.alertMessageObserver.send(value: self.alertMessage(for: errors))

                }
                self.isLoading.value = false
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
    }

    // MARK: - Commercetools image search via ML endpoint

    private func queryForImageSearchProductProjections() {
        guard let image = imageSearch.value else { return }
        productRetrievalQueue.addOperation {
            // TODO Add paging
            let semaphore = DispatchSemaphore(value: 0)
            self.isLoading.value = true
            ImageSearch.perform(for: image, limit: 50) { result in
                if let imageSearchProducts = result.model?.results, result.isSuccess {
                    let productIds = imageSearchProducts.map { $0.productVariants.first?.product?.id ?? "" }
                    var filterQuery = "id:"
                    filterQuery.append(productIds.map({ "\"\($0)\"" }).joined(separator: ","))
                    ProductProjection.search(limit: 50, filterQuery: [filterQuery]) { result in
                        if var products = result.model?.results, result.isSuccess {
                            products.sort { lhs, rhs -> Bool in
                                (productIds.firstIndex(of: lhs.id) ?? 0) < (productIds.firstIndex(of: rhs.id) ?? 0)
                            }
                            DispatchQueue.main.async {
                                if products.count > 0 && self.products.count > 0 {
                                    self.scrollToBeginningObserver.send(value: ())
                                }
                                self.products = products
                                self.filtersViewModel?.facets.value = result.model?.facets
                            }
                        } else if let errors = result.errors as? [CTError], result.isFailure {
                            self.alertMessageObserver.send(value: self.alertMessage(for: errors))

                        }
                        self.isLoading.value = false
                        semaphore.signal()
                    }
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    self.isLoading.value = false
                    semaphore.signal()
                }
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
    }

    // MARK: - Presenting product details from the universal links and notification actions

    func presentProductDetails(sku: String) {
        isLoading.value = true
        ProductProjection.search(filters: ["variants.sku:\"\(sku)\""], markMatchingVariants: true) { result in
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
    
    func presentProductDetails(productId: String) {
        isLoading.value = true
        ProductProjection.byId(productId) { result in
            if let product = result.model, result.isSuccess {
                self.presentProductDetailsObserver.send(value: ProductDetailsViewModel(product: product))
                
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }
}
