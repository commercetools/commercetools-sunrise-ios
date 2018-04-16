//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift
import Result
import SDWebImage

class ProductDetailsViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let selectSizeObserver: Signal<IndexPath, NoError>.Observer
    let selectColorObserver: Signal<IndexPath, NoError>.Observer
    var toggleWishListObserver: Signal<IndexPath, NoError>.Observer
    var toggleWishListAction: Action<Void, Void, CTError>!
    var addToCartAction: Action<Void, Void, CTError>!
    var reserveAction: Action<Void, Void, CTError>!

    // Outputs
    let name = MutableProperty("")
    let price = MutableProperty("")
    let priceColor = MutableProperty(UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0))
    let oldPrice: MutableProperty<NSAttributedString?> = MutableProperty(nil)
    let isOnStock: MutableProperty<NSAttributedString?> = MutableProperty(nil)
    let isProductInWishList = MutableProperty(false)
    let imageCount = MutableProperty(0)
    let shareUrl = MutableProperty("")
    let isLoading = MutableProperty(false)
    let recommendations = MutableProperty([ProductProjection]())
    let performSegueSignal: Signal<String, NoError>
    let signInPromptSignal: Signal<Void, NoError>

    // Dialogue texts
    let logInTitle = NSLocalizedString("Log In To Continue", comment: "Log In To Continue")
    let logInAction = NSLocalizedString("Log in", comment: "Log in")
    let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")

    let activeAttributes = MutableProperty([Attribute]())

    weak var productsViewModel: ProductOverviewViewModel?

    private var colors = [Attribute]()
    private var sizes = [Attribute]()

    var storeSelectionViewModel: StoreSelectionViewModel? {
        guard let product = product, let sku = variantForActiveAttributes?.sku else { return nil }
        return StoreSelectionViewModel(product: product, sku: sku)
    }

    private let performSegueObserver: Signal<String, NoError>.Observer
    private let signInPromptObserver: Signal<Void, NoError>.Observer
    private var product: ProductProjection?
    private lazy var productType: ProductType? = {
        return productsViewModel?.filtersViewModel?.mainProductType
    }()
    private var shareBaseURL: String = {
        var baseUrl = Bundle.main.object(forInfoDictionaryKey: "Sharing base URL") as! String
        if !baseUrl.hasSuffix("/") {
            baseUrl.append("/")
        }
        return baseUrl
    }()
    private let disposables = CompositeDisposable()

    // Attributes configuration
    private let selectableAttributes = [FiltersViewModel.kColorsAttributeName, FiltersViewModel.kSizeAttributeName]
    private var productDescriptionAttributes: [String] = {
        return Bundle.main.object(forInfoDictionaryKey: "Product description attributes") as? [String] ?? []
    }()

    // Product variant for currently active (selected) attributes
    private var variantForActiveAttributes: ProductVariant? {
        return product?.allVariants.filter({ variant in
            for activeAttribute in activeAttributes.value {
                if variant.attributes?.first(where: { $0 == activeAttribute }) == nil {
                    return false
                }
            }
            return true
        }).first
    }

    // MARK: Lifecycle

    override private init() {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectSizeSignal, selectSizeObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectSizeObserver = selectSizeObserver

        let (selectColorSignal, selectColorObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectColorObserver = selectColorObserver

        let (toggleWishListSignal, toggleWishListObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver

        (performSegueSignal, performSegueObserver) = Signal<String, NoError>.pipe()
        (signInPromptSignal, signInPromptObserver) = Signal<Void, NoError>.pipe()

        super.init()

        disposables += refreshSignal
        .observeValues { [weak self] in
            if let productId = self?.product?.id {
                self?.retrieveProduct(productId, size: nil)
            }
        }
        
        disposables += selectSizeSignal.observeValues { [unowned self] in
            self.activeAttributes.value = self.activeAttributes.value.filter { $0.name != FiltersViewModel.kSizeAttributeName }
            self.activeAttributes.value.append(self.sizes[$0.item])
        }

        disposables += selectColorSignal.observeValues { [unowned self] in
            self.activeAttributes.value = self.activeAttributes.value.filter { $0.name != FiltersViewModel.kColorsAttributeName }
            self.activeAttributes.value.append(self.colors[$0.item])
        }

        addToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            self.isLoading.value = true
            return AppRouting.cartViewController?.viewModel?.addProduct(id: self.product?.id ?? "", variantId: self.currentVariantId() ?? 0, quantity: 1, discountCode: nil) ?? SignalProducer.empty
        }

        toggleWishListAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            return AppRouting.wishListViewController?.viewModel?.toggleWishList(productId: self.product?.id ?? "", variantId: self.currentVariantId()) ?? SignalProducer.empty
        }

        reserveAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            if self.isAuthenticated {
                self.performSegueObserver.send(value: "showStoreSelection")
            } else {
                self.signInPromptObserver.send(value: ())
            }
            return SignalProducer.empty
        }

        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            let recommendation = self.recommendations.value[$0.item]
            self.disposables += AppRouting.wishListViewController?.viewModel?.toggleWishListAction.apply((recommendation.id, recommendation.displayVariant()?.id))
            .startWithCompleted { [unowned self] in
                self.recommendations.value = self.recommendations.value
            }
        }

        disposables += reserveAction.events
        .observeValues { [weak self] _ in
            self?.isLoading.value = false
        }
    }

    convenience init(product: ProductProjection, variantId: Int? = nil, productsViewModel: ProductOverviewViewModel? = nil) {
        self.init()


        self.product = product
        self.productsViewModel = productsViewModel

        let availableAttributes = productType?.attributes.map { $0.name } ?? []
        productDescriptionAttributes = productDescriptionAttributes.filter { availableAttributes.contains($0) }

        bindViewModelProperties()

        guard let variant = product.allVariants.first(where: { $0.id == variantId }) ?? product.mainVariantWithPrice else { return }
        let color = variant.attributes?.first { $0.name == FiltersViewModel.kColorsAttributeName }
        let size = variant.attributes?.first { $0.name == FiltersViewModel.kSizeAttributeName }
        if let color = color {
            activeAttributes.value.append(color)
        }
        if let size = size {
            activeAttributes.value.append(size)
        }

        retrieveRecommendations()
    }

    convenience init(productId: String, size: String? = nil) {
        self.init()
        retrieveProduct(productId, size: size)
    }
    
    deinit {
        disposables.dispose()
    }

    // MARK: Bindings

    private func bindViewModelProperties() {
        name.value = product?.name.localizedString ?? ""

        product?.displayVariants().forEach {
            if let color = $0.attributes?.filter({ $0.name == FiltersViewModel.kColorsAttributeName }).first, !colors.contains(color) {
                colors.append(color)
            }
            if let size = $0.attributes?.filter({ $0.name == FiltersViewModel.kSizeAttributeName }).first, !sizes.contains(size) {
                sizes.append(size)
            }
        }

        disposables += imageCount <~ activeAttributes.map { [weak self] _ in
            SDWebImagePrefetcher.shared().prefetchURLs(self?.variantForActiveAttributes?.images?.flatMap({ URL(string: ($0.url)) }))
            return self?.variantForActiveAttributes?.images?.count ?? 0
        }

        disposables += price <~ activeAttributes.map { [weak self] _ in
            guard let price = self?.priceForActiveAttributes else { return "" }

            if let discounted = price.discounted?.value {
                return "\(discounted)"
            } else {
                return "\(price.value)"
            }
        }

        disposables += oldPrice <~ activeAttributes.map { [weak self] _ -> NSAttributedString? in
            let oldPriceAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Bold", size: 18)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
            guard let price = self?.priceForActiveAttributes, let _ = price.discounted?.value else { return nil }

            return NSAttributedString(string: "\(price.value)", attributes: oldPriceAttributes)
        }

        disposables += isOnStock <~ activeAttributes.map { [unowned self] _ -> NSAttributedString? in
            if self.variantForActiveAttributes?.availability?.isOnStock == true {
                let onStockAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Regular", size: 12)!, .foregroundColor: UIColor(red: 0.38, green: 0.65, blue: 0.08, alpha: 1.0)]
                return NSAttributedString(string: self.onStock, attributes: onStockAttributes)
            } else {
                let notAvailableAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Regular", size: 12)!, .foregroundColor: UIColor(red: 0.82, green: 0.01, blue: 0.11, alpha: 1.0)]
                return NSAttributedString(string: self.notAvailable, attributes: notAvailableAttributes)
            }
        }

        let currentLocaleCode = Locale.components(fromIdentifier: Locale.current.identifier)[NSLocale.Key.languageCode.rawValue] ?? ""
        disposables += shareUrl <~ activeAttributes.map { [unowned self] _ in "\(self.shareBaseURL)\(currentLocaleCode)/\(self.product?.slug.localizedString ?? "")-\(self.variantForActiveAttributes?.sku ?? "").html" }

        disposables += isProductInWishList <~ activeAttributes.map { [unowned self] _ in AppRouting.wishListViewController?.viewModel?.lineItems.value.contains { $0.productId == self.product?.id && $0.variantId == self.currentVariantId() } == true }

        disposables += priceColor <~ oldPrice.map { $0 == nil || $0?.string.isEmpty == true ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0) }
    }

    // MARK: - Data Source

    var numberOfSizes: Int {
        return sizes.count
    }

    var numberOfColors: Int {
        return colors.count
    }

    func sizeName(at indexPath: IndexPath) -> String? {
        return sizes[indexPath.item].valueLabel
    }

    func isSizeActive(at indexPath: IndexPath) -> Bool {
        return variantForActiveAttributes?.attributes?.contains(sizes[indexPath.item]) ?? false
    }

    func color(at indexPath: IndexPath) -> UIColor? {
        return FiltersViewModel.colorValues[colors[indexPath.item].valueKey ?? ""]
    }

    func isColorActive(at indexPath: IndexPath) -> Bool {
        return variantForActiveAttributes?.attributes?.contains(colors[indexPath.item]) ?? false
    }

    // MARK: - Images Collection View

    func productImageUrl(at indexPath: IndexPath) -> String {
        return variantForActiveAttributes?.images?[indexPath.item].url ?? ""
    }

    // MARK: - Recommendations

    var numberOfRecommendations: Int {
        return recommendations.value.count
    }

    func recommendationName(at indexPath: IndexPath) -> String {
        return recommendations.value[indexPath.item].name.localizedString ?? ""
    }

    func recommendationImageUrl(at indexPath: IndexPath) -> String {
        return recommendations.value[indexPath.row].displayVariant()?.images?.first?.url ?? ""
    }

    func recommendationPrice(at indexPath: IndexPath) -> String {
        guard let variant = recommendations.value[indexPath.row].displayVariant(),
              let price = variant.price() else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }

    func recommendationOldPrice(at indexPath: IndexPath) -> String {
        guard let variant = recommendations.value[indexPath.row].displayVariant(),
              let price = variant.price(),
              price.discounted?.value != nil else { return "" }

        return price.value.description
    }

    func isProductInWishList(at indexPath: IndexPath) -> Bool {
        let recommendation = recommendations.value[indexPath.row]
        return AppRouting.wishListViewController?.viewModel?.lineItems.value.contains { $0.productId == recommendation.id && $0.variantId == recommendation.displayVariant()?.id} == true
    }

    func productDetailsViewModelForRecommendation(at indexPath: IndexPath) -> ProductDetailsViewModel {
        let product = recommendations.value[indexPath.row]
        let variant = recommendations.value[indexPath.row].displayVariant()
        let viewModel = ProductDetailsViewModel(product: product, variantId: variant?.id, productsViewModel: productsViewModel)
        return viewModel
    }

    // MARK: - Product Description

    var numberOfDescriptionCells: Int {
        return productDescriptionAttributes.count
    }

    func descriptionTitle(at indexPath: IndexPath) -> String? {
        return productType?.attributes.first(where: { $0.name == productDescriptionAttributes[indexPath.row] })?.label.localizedString?.uppercased()
    }

    func descriptionValue(at indexPath: IndexPath) -> String? {
        guard let attributeDefinition = productType?.attributes.first(where: { $0.name == productDescriptionAttributes[indexPath.row] }) else { return "N/A" }
        return variantForActiveAttributes?.attributes?.first(where: { $0.name == productDescriptionAttributes[indexPath.row] })?.value(attributeDefinition.type) ?? "N/A"
    }

    // MARK: Internal Helpers

    private var priceForActiveAttributes: Price? {
        return variantForActiveAttributes?.price()
    }

    private func currentVariantId() -> Int? {
        return variantForActiveAttributes?.id
    }

    // MARK: - Product retrieval

    private func retrieveProduct(_ productId: String, size: String?) {
        self.isLoading.value = true
        ProductProjection.byId(productId, expansion: ["productType"], result: { result in
            if let product = result.model, result.isSuccess {
                self.product = product
                self.productType = product.productType.obj
                self.bindViewModelProperties()
                // TODO Set size
//                if let size = size {
//                    self.activeAttributes.value["size"] = size
//                }

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        })
    }

    private func retrieveRecommendations() {
        let categoriesFilterQuery = product?.categories.reduce(into: [String](), { $0.append("categories.id:subtree(\"\($1.id)\")") }) ?? []
        let popCategoryFilterQuery = productsViewModel?.category.value != nil ? ["categories.id:subtree(\"\(productsViewModel!.category.value!.id)\")"] : nil

        ProductProjection.search(limit: 10, filterQuery: popCategoryFilterQuery ?? categoriesFilterQuery, markMatchingVariants: true,
                                 priceCurrency: AppDelegate.currentCurrency, priceCountry: AppDelegate.currentCountry,
                                 priceCustomerGroup: AppDelegate.customerGroup?.id) { result in
            // In case we used category from POP to filter recommendations, and less than 5 results were returned,
            // try again by taking into account all categories this product belongs to
            if let count = result.model?.count, count < 5, popCategoryFilterQuery != nil {
                ProductProjection.search(limit: 10, filterQuery: categoriesFilterQuery, markMatchingVariants: true,
                                         priceCurrency: AppDelegate.currentCurrency, priceCountry: AppDelegate.currentCountry,
                                         priceCustomerGroup: AppDelegate.customerGroup?.id) { result in
                    if let products = result.model?.results {
                        self.recommendations.value = products.filter { $0.id != self.product?.id }
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                }

            } else if let products = result.model?.results {
                self.recommendations.value = products.filter { $0.id != self.product?.id }
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
        }
    }
}

extension Attribute {
    var valueLabel: String? {
        return value.dictionary?["label"]?.string
    }
    var valueKey: String? {
        return value.dictionary?["key"]?.string
    }
}
