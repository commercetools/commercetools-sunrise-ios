//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift
import Result

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
    let imageCount = MutableProperty(0)
    let quantities = (1...9).map { String($0) }
    let isLoading = MutableProperty(false)
    var isLoggedIn: Bool {
        return AppRouting.isLoggedIn
    }

    // Dialogue texts
    let addToCartSuccessTitle = NSLocalizedString("Product added to cart", comment: "Product added to cart")
    let addToCartSuccessMessage = NSLocalizedString("Would you like to continue looking for more, or go to cart overview?", comment: "Product added to cart message")
    let continueTitle = NSLocalizedString("Continue", comment: "Continue")
    let cartOverviewTitle = NSLocalizedString("Cart overview", comment: "Cart overview")
    let addToCartFailedTitle = NSLocalizedString("Couldn't add product to cart", comment: "Adding product to cart failed")

    let logInTitle = NSLocalizedString("Log In To Continue", comment: "Log In To Continue")
    let logInMessage = NSLocalizedString("In order to make a reservation, you have to log in first.", comment: "Reservation log in prompt")
    let logInAction = NSLocalizedString("Log in", comment: "Log in")
    let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")

    // Actions
    lazy var addToCartAction: Action<String, Void, CTError> = { [unowned self] in
        return Action(enabledIf: Property(value: true), { quantity in
            self.isLoading.value = true
            return self.addLineItem(quantity: quantity)
        })
    }()

    var storeSelectionViewModel: StoreSelectionViewModel? {
        guard let product = product else { return nil }
        return StoreSelectionViewModel(product: product, sku: sku.value)
    }

    private var product: ProductProjection?

    // Attributes configuration
    private let selectableAttributes: [String] = {
        return Bundle.main.object(forInfoDictionaryKey: "Selectable attributes") as? [String] ?? []
    }()
    private let displayableAttributes: [String] = {
        return Bundle.main.object(forInfoDictionaryKey: "Displayable attributes") as? [String] ?? []
    }()

    // Product variant for currently active (selected) attributes
    private var variantForActiveAttributes: ProductVariant? {
        let allVariants = product?.allVariants
        return allVariants?.filter({ variant in
            for activeAttribute in activeAttributes.value {
                if let type = typeForAttributeName(activeAttribute.0),
                let attributeValue = variant.attributes?.filter({ $0.name == activeAttribute.0 }).first?.value(type), attributeValue != activeAttribute.1
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
        .observeValues { [weak self] in
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
        name.value = product?.name?.localizedString?.uppercased() ?? ""

        let allVariants = product?.allVariants

        (selectableAttributes + displayableAttributes).forEach { attribute in
            if let type = typeForAttributeName(attribute) {
                var values = [String]()

                // We want to show attribute values only for those variants that have prices available
                if let masterVariant = product?.masterVariant, let prices = masterVariant.prices,
                        let defaultValue = masterVariant.attributes?.filter({ $0.name == attribute }).first?.value(type) ,
                        prices.count > 0 {
                    values.append(defaultValue)
                }
                product?.variants?.filter({ ($0.prices?.count ?? 0) > 0 }).forEach { variant in
                    if let value = variant.attributes?.filter({ $0.name == attribute }).first?.value(type) {
                        if !values.contains(value) {
                            values.append(value)
                        }
                    }
                }

                self.attributes.value[attribute] = values
                activeAttributes.value[attribute] = values.first ?? "N/A"

                if let matchingVariant = allVariants?.filter({ $0.isMatchingVariant ?? false }).first,
                        let matchingValue = matchingVariant.attributes?.filter({ $0.name == attribute }).first?.value(type) {
                    activeAttributes.value[attribute] = matchingValue
                }
            }
        }

        sku <~ activeAttributes.producer.map { [weak self] _ in
            return self?.variantForActiveAttributes?.sku ?? ""
        }

        imageCount <~ activeAttributes.producer.map { [weak self] _ in
            return self?.variantForActiveAttributes?.images?.count ?? 0
        }

        price <~ activeAttributes.producer.map { [weak self] _ in
            guard let price = self?.priceForActiveAttributes, let value = price.value else { return "" }

            if let discounted = price.discounted?.value {
                return "\(discounted)"
            } else {
                return "\(value)"
            }
        }

        oldPrice <~ activeAttributes.producer.map { [weak self] _ in
            guard let price = self?.priceForActiveAttributes, let value = price.value, let _ = price.discounted?.value else { return "" }

            return "\(value)"
        }

        self.isLoading.value = false
    }

    // MARK: - Data Source

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch section {
            case 0: return selectableAttributes.count
            case 2: return displayableAttributes.count
            default: return 0
        }
    }

    func attributeNameAtIndexPath(_ indexPath: IndexPath) -> String? {
        let attribute = indexPath.section == 0 ? selectableAttributes[indexPath.row] : displayableAttributes[indexPath.row]
        return product?.productType?.obj?.attributes?.filter({ $0.name == attribute }).first?.label?.localizedString?.uppercased()
    }

    func attributeKeyAtIndexPath(_ indexPath: IndexPath) -> String {
        return indexPath.section == 0 ? selectableAttributes[indexPath.row] : displayableAttributes[indexPath.row]
    }

    func isAttributeSelectableAtIndexPath(_ indexPath: IndexPath) -> Bool {
        return (attributes.value[selectableAttributes[indexPath.row]]?.count ?? 0) > 1
    }

    // MARK: - Images Collection View

    func numberOfItems(in section: Int) -> Int {
        return variantForActiveAttributes?.images?.count ?? 0
    }

    func productImageUrl(at indexPath: IndexPath) -> String {
        return variantForActiveAttributes?.images?[indexPath.item].url ?? ""
    }

    // MARK: Internal Helpers

    private var priceForActiveAttributes: Price? {
        return variantForActiveAttributes?.independentPrice
    }

    private func currentVariantId() -> Int? {
        return product?.allVariants.filter({ $0.sku == sku.value }).first?.id
    }

    private func typeForAttributeName(_ name: String) -> AttributeType? {
        return product?.productType?.obj?.attributes?.filter({ $0.name == name }).first?.type
    }

    // MARK: - Cart interaction

    private func addLineItem(quantity: String = "1") -> SignalProducer<Void, CTError> {
        return SignalProducer { observer, disposable in

            Cart.active(result: { result in
                if let cart = result.model, let cartId = cart.id, let version = cart.version, result.isSuccess {
                    // In case we already have an active cart, just add selected product
                    var options = AddLineItemOptions()
                    options.productId = self.product?.id
                    options.variantId = self.currentVariantId()
                    options.quantity = UInt(quantity)
                    let updateActions = UpdateActions(version: version, actions: [CartUpdateAction.addLineItem(options: options)])
                    Cart.update(cartId, actions: updateActions, result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let errors = result.errors as? [CTError], result.isFailure {
                            super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                        }
                        self.isLoading.value = false
                    })

                } else if let error = result.errors?.first as? CTError, case .resourceNotFoundError(let reason) = error,
                          reason.message == "No active cart exists." {
                    // If there is no active cart, create one, with the selected product
                    var cartDraft = CartDraft()
                    cartDraft.currency = self.currencyCodeForCurrentLocale
                    var lineItemDraft = LineItemDraft()
                    lineItemDraft.productId = self.product?.id
                    lineItemDraft.variantId = self.currentVariantId()
                    lineItemDraft.quantity = UInt(quantity)
                    cartDraft.lineItems = [lineItemDraft]

                    Cart.create(cartDraft, result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                        self.isLoading.value = false
                    })

                } else if let error = result.errors?.first as? CTError {
                    observer.send(error: error)
                    self.isLoading.value = false
                }
            })
        }
    }

    // MARK: - Product retrieval

    private func retrieveProduct(_ productId: String, size: String?) {
        self.isLoading.value = true
        ProductProjection.byId(productId, expansion: ["productType"], result: { result in
            if let product = result.model, result.isSuccess {
                self.product = product
                self.bindViewModelProducers()
                if let size = size {
                    self.activeAttributes.value["size"] = size
                }

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
        })
    }

    private func retrieveProductType() {
        guard let id = product?.productType?.id else { return }
        self.isLoading.value = true

        ProductType.byId(id, expansion: nil, result: { result in
            if let productType = result.model, result.isSuccess {
                self.product?.productType?.obj = productType
                self.bindViewModelProducers()

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
        })
    }
}
