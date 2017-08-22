//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let addDiscountCodeObserver: Signal<String, NoError>.Observer
    let deleteLineItemObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let isLoading: MutableProperty<Bool>
    let taxRowHidden = MutableProperty(false)
    let numberOfItems = MutableProperty("")
    let subtotal = MutableProperty("")
    let orderDiscount = MutableProperty("")
    let tax = MutableProperty("")
    let orderTotal = MutableProperty("")
    let orderDiscountButton: MutableProperty<(text: String, isEnabled: Bool)>
    let contentChangesSignal: Signal<Changeset, NoError>
    let discountsDetailsSignal: Signal<String, NoError>
    let showDiscountDialogueSignal: Signal<Void, NoError>
    let availableQuantities = (1...9).map { String($0) }
    let performSegueSignal: Signal<String, NoError>

    // Actions
    lazy var checkoutAction: Action<Void, Void, NoError> = { [weak self] in
        return Action(enabledIf: Property(value: true)) { [weak self] _ in
            if Commercetools.authState == .customerToken {
                self?.performSegueObserver.send(value: "showAddressSelection")
            } else {
                self?.performSegueObserver.send(value: "showNewAddress")
            }
            return SignalProducer.empty
        }
    }()
    lazy var discountDetailsAction: Action<Void, Void, NoError> = { [weak self] in
        return Action(enabledIf: Property(value: true)) { [weak self] _ in
            guard let discountsDetailsObserver = self?.discountsDetailsObserver,
                  let discountsDetails = self?.discountsDetails else { return SignalProducer.empty }
            discountsDetailsObserver.send(value: discountsDetails)
            return SignalProducer.empty
        }
    }()
    lazy var showDiscountDialogueAction: Action<Void, Void, NoError> = { [weak self] in
        return Action(enabledIf: Property(value: true)) { [weak self] _ in
            self?.showDiscountDialogueObserver.send(value: ())
            return SignalProducer.empty
        }
    }()

    // Dialogue texts
    let discountsTitle = NSLocalizedString("Discounts", comment: "Discounts")
    let addDiscountMessage = NSLocalizedString("Add your discount code:", comment: "Add discount code message")
    // Placeholders
    let discountCodePlaceholder = NSLocalizedString("Discount code", comment: "Discount code")
    private let discountCodeButtonText = NSLocalizedString("Order Discount", comment: "Order Discount")

    let cart: MutableProperty<Cart?>

    private let contentChangesObserver: Signal<Changeset, NoError>.Observer
    private let deleteLineItemSignal: Signal<IndexPath, NoError>
    private let performSegueObserver: Signal<String, NoError>.Observer
    private let discountsDetailsObserver: Signal<String, NoError>.Observer
    private let showDiscountDialogueObserver: Signal<Void, NoError>.Observer
    private let addDiscountCodeSignal: Signal<String, NoError>
    private let discountCodesExpansion = ["discountCodes[*].discountCode.cartDiscounts[*]"]
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(false)
        (performSegueSignal, performSegueObserver) = Signal<String, NoError>.pipe()
        (showDiscountDialogueSignal, showDiscountDialogueObserver) = Signal<Void, NoError>.pipe()
        (discountsDetailsSignal, discountsDetailsObserver) = Signal<String, NoError>.pipe()
        (addDiscountCodeSignal, addDiscountCodeObserver) = Signal<String, NoError>.pipe()
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        let (deleteLineItemSignal, deleteLineItemObserver) = Signal<IndexPath, NoError>.pipe()
        self.deleteLineItemSignal = deleteLineItemSignal
        self.deleteLineItemObserver = deleteLineItemObserver

        cart = MutableProperty(nil)
        numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems.count ?? 0) }
        orderDiscountButton = MutableProperty((text: discountCodeButtonText, isEnabled: false))

        super.init()

        subtotal <~ cart.producer.map { [unowned self] _ in self.calculateSubtotal() }
        orderTotal <~ cart.producer.map { [unowned self] _ in self.orderTotal(for: self.cart.value) }
        tax <~ cart.producer.map { [unowned self] _ in self.calculateTax() }
        taxRowHidden <~ tax.producer.map { tax in tax == "" }
        orderDiscount <~ cart.producer.map { [unowned self] _ in self.calculateOrderDiscount() }
        orderDiscountButton <~ cart.producer.map { [unowned self] cart in
            if let discounts = cart?.discountCodes, discounts.count > 0 {
                return (text: "\(self.discountCodeButtonText) ℹ️", isEnabled: true)
            } else {
                return (text: self.discountCodeButtonText, isEnabled: false)
            }
        }

        disposables += refreshSignal.observeValues { [weak self] in
            self?.queryForActiveCart()
        }

        disposables += addDiscountCodeSignal.observeValues { [weak self] discountCode in
            self?.add(discountCode: discountCode)
        }

        disposables += deleteLineItemSignal.observeValues { [weak self] indexPath in
            self?.deleteLineItemAtIndexPath(indexPath)
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Discount codes

    private var discountsDetails: String {
        guard let discounts = cart.value?.discountCodes, discounts.count > 0 else { return "" }

        return discounts.reduce("", { "\($0)\n\($1.discountCode.obj?.discountDetails ?? "")"})
    }

    // MARK: - Data Source

    func numberOfRowsInSection(_ section: Int) -> Int {
        if let lineItemsCount = cart.value?.lineItems.count, lineItemsCount > 0 {
            return lineItemsCount + 1
        } else {
            return 0
        }
    }

    func canDeleteRowAtIndexPath(_ indexPath: IndexPath) -> Bool {
        return indexPath.row != numberOfRowsInSection(0) - 1
    }

    func lineItemNameAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].name.localizedString ?? ""
    }

    func lineItemSkuAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.sku ?? ""
    }

    func lineItemSizeAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.attributes?.filter({ $0.name == "size" }).first?.value.string ?? "N/A"
    }

    func lineItemImageUrlAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.images?.first?.url ?? ""
    }

    func lineItemOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems[indexPath.row], lineItem.price.discounted?.value != nil || lineItem.discountedPricePerQuantity.count > 0  else { return "" }

        return lineItem.price.value.description
    }

    func lineItemPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems[indexPath.row] else { return "" }

        if let discounted = lineItem.price.discounted?.value {
            return discounted.description

        } else if let discounted = lineItem.discountedPricePerQuantity.first?.discountedPrice.value {
            return discounted.description

        } else {
            return lineItem.price.value.description
        }
    }

    func lineItemQuantityAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].quantity.description ?? "0"
    }

    func lineItemTotalPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].totalPrice.description ?? "N/A"
    }

    func updateLineItemQuantityAtIndexPath(_ indexPath: IndexPath, quantity: String) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems[indexPath.row].id,
                let quantity = UInt(quantity) {
            self.isLoading.value = true

            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.changeLineItemQuantity(lineItemId: lineItemId, quantity: quantity),
                                                                                            .recalculate(updateProductData: nil)])
            Cart.update(cartId, actions: updateActions, expansion: discountCodesExpansion, result: { result in
                if let cart = result.model, result.isSuccess {
                    self.update(cart: cart)
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self.update(cart: nil)
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                }
                self.isLoading.value = false
            })
        }
    }

    func productDetailsViewModelForLineItemAtIndexPath(_ indexPath: IndexPath) -> ProductViewModel? {
        if let productId = cart.value?.lineItems[indexPath.row].productId {
            return ProductViewModel(productId: productId, size: lineItemSizeAtIndexPath(indexPath))
        }
        return nil
    }

    private func deleteLineItemAtIndexPath(_ indexPath: IndexPath) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems[indexPath.row].id {
            self.isLoading.value = true

            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.removeLineItem(lineItemId: lineItemId, quantity: nil),
                                                                                           .recalculate(updateProductData: nil)])
            Cart.update(cartId, actions: updateActions, expansion: discountCodesExpansion, result: { result in
                if let cart = result.model, result.isSuccess {
                    self.update(cart: cart)
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self.update(cart: nil)
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                }
                self.isLoading.value = false
            })
        }
    }

    // MARK: - Cart retrieval

    private func queryForActiveCart(completion: ((Cart)->())? = nil) {
        isLoading.value = true

        Cart.active(result: { result in
            if let cart = result.model, result.isSuccess {
                // Run recalculation before we present the refreshed cart
                Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: [.recalculate(updateProductData: nil)]), expansion: self.discountCodesExpansion, result: { result in
                    if let cart = result.model, result.isSuccess {
                        self.update(cart: cart)
                        completion?(cart)
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        self.update(cart: nil)
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            } else {
                // If there is no active cart, create one, with the selected product
                let cartDraft = CartDraft(currency: BaseViewModel.currencyCodeForCurrentLocale)
                Cart.create(cartDraft, expansion: self.discountCodesExpansion, result: { result in
                    if let cart = result.model, result.isSuccess {
                        self.update(cart: cart)
                        completion?(cart)
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        self.update(cart: nil)
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            }
        })
    }

    private func update(cart: Cart?) {
        let previousCart = self.cart.value

        var changeset = Changeset()

        if let previousCart = previousCart, let newCart = cart {
            let oldLineItems = previousCart.lineItems
            let newLineItems = newCart.lineItems

            var deletions = [IndexPath]()
            var modifications = [IndexPath]()
            for (i, lineItem) in oldLineItems.enumerated() {
                if !newLineItems.contains(lineItem) {
                    deletions.append(IndexPath(row: i, section:0))
                } else {
                    modifications.append(IndexPath(row: i, section:0))
                }
            }

            if newLineItems.count > 0 && oldLineItems.count > 0 {
                modifications.append(IndexPath(row: oldLineItems.count, section: 0))
            }
            changeset.modifications = modifications
            if newLineItems.count == 0 && oldLineItems.count > 0 {
                deletions.append(IndexPath(row: oldLineItems.count, section: 0))
            }
            changeset.deletions = deletions

            var insertions = [IndexPath]()
            for (i, lineItem) in newLineItems.enumerated() {
                if !oldLineItems.contains(lineItem) {
                    insertions.append(IndexPath(row: i, section:0))
                }
            }
            if oldLineItems.count == 0 && newLineItems.count > 0 {
                insertions.append(IndexPath(row: newLineItems.count, section:0))
            }
            changeset.insertions = insertions

        } else if let previousCart = previousCart, cart == nil && previousCart.lineItems.count > 0  {
            changeset.deletions = (0...(previousCart.lineItems.count)).map { IndexPath(row: $0, section: 0) }

        } else if let lineItemsCount = cart?.lineItems.count, lineItemsCount > 0 {
            changeset.insertions = (0...lineItemsCount).map { IndexPath(row: $0, section: 0) }
        }

        self.cart.value = cart
        contentChangesObserver.send(value: changeset)
    }
    
    // MARK: - Cart overview calculations

    private func calculateSubtotal() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }
        return calculateSubtotal(lineItems)
    }

    private func calculateTax() -> String {
        guard let cart = cart.value, let totalGrossAmount = cart.taxedPrice?.totalGross.centAmount,
        let totalNetAmount = cart.taxedPrice?.totalNet.centAmount else { return "" }

        return Money(currencyCode: cart.lineItems.first?.totalPrice.currencyCode ?? "",
                centAmount: totalGrossAmount - totalNetAmount).description
    }

    private func calculateOrderDiscount() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }
        return calculateOrderDiscount(lineItems)
    }

    // MARK: - Add product to the currently active cart

    func addProduct(id: String, variantId: Int, quantity: UInt, discountCode: String?) {
        queryForActiveCart { [weak self] cart in
            var actions = [CartUpdateAction.addLineItem(lineItemDraft: LineItemDraft(productVariantSelection: .productVariant(productId: id, variantId: variantId), quantity: quantity))]
            if let discountCode = discountCode {
                actions.append(.addDiscountCode(code: discountCode))
            }
            self?.isLoading.value = true
            Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: actions), expansion: self?.discountCodesExpansion, result: { [weak self] result in
                if let cart = result.model, result.isSuccess {
                    self?.update(cart: cart)

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self?.alertMessageObserver.send(value: self?.alertMessage(for: errors) ?? "")
                }
                self?.isLoading.value = false
            })
        }
    }

    // MARK: - Apply discount code to the currently active cart

    func add(discountCode: String) {
        queryForActiveCart { [weak self] cart in
            let actions = [CartUpdateAction.addDiscountCode(code: discountCode), .recalculate(updateProductData: nil)]
            self?.isLoading.value = true
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: actions), expansion: self?.discountCodesExpansion, result: { [weak self] result in
                if let cart = result.model, result.isSuccess {
                    self?.update(cart: cart)

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self?.alertMessageObserver.send(value: self?.alertMessage(for: errors) ?? "")
                }
                self?.isLoading.value = false
            })
        }
    }
}
