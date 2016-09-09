//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveCocoa
import Result
import ObjectMapper

class ProductViewModel: BaseViewModel {

    // Inputs
    let activeAttributes = MutableProperty([String: String]())
    let refreshObserver: Observer<Void, NoError>

    // Outputs
    let attributes = MutableProperty([String: [String]]())
    let name = MutableProperty("")
    let sku = MutableProperty("")
    let price = MutableProperty("")
    let oldPrice = MutableProperty("")
    let imageUrl = MutableProperty("")
    let quantities = (1...9).map { String($0) }
    let isLoading = MutableProperty(false)

    // Dialogue texts
    let addToCartSuccessTitle = NSLocalizedString("Product added to cart", comment: "Product added to cart")
    let addToCartSuccessMessage = NSLocalizedString("Would you like to continue looking for more, or go to cart overview?", comment: "Product added to cart message")
    let continueTitle = NSLocalizedString("Continue", comment: "Continue")
    let cartOverviewTitle = NSLocalizedString("Cart overview", comment: "Cart overview")
    let addToCartFailedTitle = NSLocalizedString("Couldn't add product to cart", comment: "Adding product to cart failed")

    // Actions
    lazy var addToCartAction: Action<String, Void, NSError> = { [unowned self] in
        return Action(enabledIf: ConstantProperty(true), { quantity in
            self.isLoading.value = true
            return self.addLineItem(quantity)
        })
    }()

    var storeSelectionViewModel: StoreSelectionViewModel? {
        guard let product = product else { return nil }
        return StoreSelectionViewModel(product: product, sku: sku.value)
    }

    private var product: ProductProjection?

    // Attributes configuration
    private let selectableAttributes: [String] = {
        return NSBundle.mainBundle().objectForInfoDictionaryKey("Selectable attributes") as? [String] ?? []
    }()
    private let displayableAttributes: [String] = {
        return NSBundle.mainBundle().objectForInfoDictionaryKey("Displayable attributes") as? [String] ?? []
    }()

    // Product variant for currently active (selected) attributes
    private var variantForActiveAttributes: ProductVariant? {
        let allVariants = product?.allVariants
        return allVariants?.filter({ variant in
            for activeAttribute in activeAttributes.value {
                if let type = typeForAttributeName(activeAttribute.0),
                attributeValue = variant.attributes?.filter({ $0.name == activeAttribute.0 }).first?.value(type) where attributeValue != activeAttribute.1
                        || variant.attributes?.filter({ $0.name == activeAttribute.0 }).count == 0 {
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

        super.init()

        refreshSignal
        .observeNext { [weak self] in
            if let productId = self?.product?.id {
                self?.retrieveProduct(productId, size: nil)
            }
        }
    }

    convenience init(product: ProductProjection) {
        self.init()

        self.product = product
        retrieveProductType()
    }

    convenience init(productId: String, size: String? = nil) {
        self.init()
        retrieveProduct(productId, size: size)
    }

    // MARK: Bindings

    private func bindViewModelProducers() {
        name.value = product?.name?.localizedString?.uppercaseString ?? ""

        let allVariants = product?.allVariants

        (selectableAttributes + displayableAttributes).forEach { attribute in
            if let type = typeForAttributeName(attribute) {
                var values = [String]()

                // We want to show attribute values only for those variants that have prices available
                if let masterVariant = product?.masterVariant, prices = masterVariant.prices,
                        defaultValue = masterVariant.attributes?.filter({ $0.name == attribute }).first?.value(type) where
                        prices.count > 0 {
                    values.append(defaultValue)
                }
                product?.variants?.filter({ $0.prices?.count > 0 }).forEach { variant in
                    if let value = variant.attributes?.filter({ $0.name == attribute }).first?.value(type) {
                        if !values.contains(value) {
                            values.append(value)
                        }
                    }
                }

                self.attributes.value[attribute] = values
                activeAttributes.value[attribute] = values.first ?? "N/A"

                if let matchingVariant = allVariants?.filter({ $0.isMatchingVariant ?? false }).first,
                        matchingValue = matchingVariant.attributes?.filter({ $0.name == attribute }).first?.value(type) {
                    activeAttributes.value[attribute] = matchingValue
                }
            }
        }

        sku <~ activeAttributes.producer.map { [weak self] _ in
            return self?.variantForActiveAttributes?.sku ?? ""
        }

        imageUrl <~ activeAttributes.producer.map { [weak self] _ in
            return self?.variantForActiveAttributes?.images?.first?.url ?? ""
        }

        price <~ activeAttributes.producer.map { [weak self] _ in
            guard let price = self?.priceForActiveAttributes, value = price.value else { return "" }

            if let discounted = price.discounted?.value {
                return "\(discounted)"
            } else {
                return "\(value)"
            }
        }

        oldPrice <~ activeAttributes.producer.map { [weak self] _ in
            guard let price = self?.priceForActiveAttributes, value = price.value, _ = price.discounted?.value else { return "" }

            return "\(value)"
        }

        self.isLoading.value = false
    }

    // MARK: - Data Source

    func numberOfRowsInSection(section: Int) -> Int {
        switch section {
            case 0: return selectableAttributes.count
            case 2: return displayableAttributes.count
            default: return 0
        }
    }

    func attributeNameAtIndexPath(indexPath: NSIndexPath) -> String? {
        let attribute = indexPath.section == 0 ? selectableAttributes[indexPath.row] : displayableAttributes[indexPath.row]
        return product?.productType?.attributes?.filter({ $0.name == attribute }).first?.label?.localizedString?.uppercaseString
    }

    func attributeKeyAtIndexPath(indexPath: NSIndexPath) -> String {
        return indexPath.section == 0 ? selectableAttributes[indexPath.row] : displayableAttributes[indexPath.row]
    }

    func isAttributeSelectableAtIndexPath(indexPath: NSIndexPath) -> Bool {
        return attributes.value[selectableAttributes[indexPath.row]]?.count > 1
    }

    // MARK: Internal Helpers

    private var priceForActiveAttributes: Price? {
        return variantForActiveAttributes?.independentPrice
    }

    private func currentVariantId() -> Int? {
        return product?.allVariants.filter({ $0.sku == sku.value }).first?.id
    }

    private func typeForAttributeName(name: String) -> AttributeType? {
        return product?.productType?.attributes?.filter({ $0.name == name }).first?.type
    }

    // MARK: - Cart interaction

    private func addLineItem(quantity: String = "1") -> SignalProducer<Void, NSError> {
        return SignalProducer { observer, disposable in

            var lineItemDraft: [String: AnyObject] = ["productId": self.product?.id ?? "", "variantId": self.currentVariantId() ?? 1, "quantity": Int(quantity) ?? 1]

            // Get the cart with state Active which has the most recent lastModifiedAt.
            Commercetools.Cart.query(predicates: ["cartState=\"Active\""], sort: ["lastModifiedAt desc"], limit: 1, result: { result in
                if let results = result.response?["results"] as? [[String: AnyObject]],
                        carts = Mapper<Cart>().mapArray(results), cart = carts.first, id = cart.id,
                        version = cart.version where result.isSuccess {
                    // In case we already have an active cart, just add selected product
                    lineItemDraft["action"] = "addLineItem"
                    Commercetools.Cart.update(id, version: version, actions: [lineItemDraft], result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let errors = result.errors where result.isFailure {
                            super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                        }
                        self.isLoading.value = false
                    })

                } else if let error = result.errors?.first where result.isFailure {
                    observer.sendFailed(error)
                    self.isLoading.value = false

                } else {
                    // If there is no active cart, create one, with the selected product
                    Commercetools.Cart.create(["currency": self.currencyCodeForCurrentLocale, "lineItems": [lineItemDraft]], result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let error = result.errors?.first where result.isFailure {
                            observer.sendFailed(error)
                        }
                        self.isLoading.value = false
                    })
                }
            })
        }
    }

    // MARK: - Product retrieval

    private func retrieveProduct(productId: String, size: String?) {
        self.isLoading.value = true
        Commercetools.ProductProjection.byId(productId, expansion: ["productType"], result: { result in
            if let product = Mapper<ProductProjection>().map(result.response) where result.isSuccess {
                self.product = product
                self.bindViewModelProducers()
                if let size = size {
                    self.activeAttributes.value["size"] = size
                }

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                self.isLoading.value = false
            }
        })
    }

    private func retrieveProductType() {
        guard let id = product?.productTypeId else { return }
        self.isLoading.value = true

        Commercetools.ProductType.byId(id, expansion: nil, result: { result in
            if let productType = Mapper<ProductType>().map(result.response) where result.isSuccess {
                self.product?.productType = productType
                self.bindViewModelProducers()

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                self.isLoading.value = false
            }
        })
    }

}