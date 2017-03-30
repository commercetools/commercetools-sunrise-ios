//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let deleteLineItemObserver: Observer<IndexPath, NoError>

    // Outputs
    let isLoading: MutableProperty<Bool>
    let taxRowHidden = MutableProperty(false)
    let numberOfItems = MutableProperty("")
    let subtotal = MutableProperty("")
    let orderDiscount = MutableProperty("")
    let tax = MutableProperty("")
    let orderTotal = MutableProperty("")
    let contentChangesSignal: Signal<Changeset, NoError>
    let availableQuantities = (1...9).map { String($0) }
    let performSegueSignal: Signal<String, NoError>

    // Actions
    lazy var checkoutAction: Action<Void, Void, NoError> = { [weak self] in
        return Action(enabledIf: Property(value: true), { [weak self] _ in
            if Commercetools.authState == .customerToken {
                self?.performSegueObserver.send(value: "showAddressSelection")
            } else {
                self?.performSegueObserver.send(value: "showNewAddress")
            }
            return SignalProducer.empty
        })
    }()

    let cart: MutableProperty<Cart?>

    private let contentChangesObserver: Observer<Changeset, NoError>
    private let deleteLineItemSignal: Signal<IndexPath, NoError>
    private let performSegueObserver: Observer<String, NoError>

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(false)
        (performSegueSignal, performSegueObserver) = Signal<String, NoError>.pipe()
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        let (deleteLineItemSignal, deleteLineItemObserver) = Signal<IndexPath, NoError>.pipe()
        self.deleteLineItemSignal = deleteLineItemSignal
        self.deleteLineItemObserver = deleteLineItemObserver

        cart = MutableProperty(nil)
        numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems?.count ?? 0) }

        super.init()

        subtotal <~ cart.producer.map { [unowned self] _ in self.calculateSubtotal() }
        orderTotal <~ cart.producer.map { [unowned self] _ in self.orderTotal(for: self.cart.value) }
        tax <~ cart.producer.map { [unowned self] _ in self.calculateTax() }
        taxRowHidden <~ tax.producer.map { tax in tax == "" }
        orderDiscount <~ cart.producer.map { [unowned self] _ in self.calculateOrderDiscount() }

        refreshSignal.observeValues { [weak self] in
            self?.queryForActiveCart()
        }

        deleteLineItemSignal.observeValues { [weak self] indexPath in
            self?.deleteLineItemAtIndexPath(indexPath)
        }
    }

    // MARK: - Data Source

    func numberOfRowsInSection(_ section: Int) -> Int {
        if let lineItemsCount = cart.value?.lineItems?.count, lineItemsCount > 0 {
            return lineItemsCount + 1
        } else {
            return 0
        }
    }

    func canDeleteRowAtIndexPath(_ indexPath: IndexPath) -> Bool {
        return indexPath.row != numberOfRowsInSection(0) - 1
    }

    func lineItemNameAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].name?.localizedString ?? ""
    }

    func lineItemSkuAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.sku ?? ""
    }

    func lineItemSizeAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.attributes?.filter({ $0.name == "size" }).first?.value as? String ?? "N/A"
    }

    func lineItemImageUrlAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.images?.first?.url ?? ""
    }

    func lineItemOldPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems?[indexPath.row], let price = lineItem.price, let value = price.value ,
                price.discounted?.value != nil || (lineItem.discountedPricePerQuantity?.count ?? 0) > 0  else { return "" }

        return value.description
    }

    func lineItemPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems?[indexPath.row], let price = lineItem.price, let value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description

        } else if let discounted = lineItem.discountedPricePerQuantity?.first?.discountedPrice?.value {
            return discounted.description

        } else {
            return value.description
        }
    }

    func lineItemQuantityAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].quantity?.description ?? "0"
    }

    func lineItemTotalPriceAtIndexPath(_ indexPath: IndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].totalPrice?.description ?? "N/A"
    }

    func updateLineItemQuantityAtIndexPath(_ indexPath: IndexPath, quantity: String) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems?[indexPath.row].id,
                let quantity = UInt(quantity) {
            self.isLoading.value = true

            var options = ChangeLineItemQuantityOptions()
            options.lineItemId = lineItemId
            options.quantity = quantity
            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.changeLineItemQuantity(options: options),
                                                                                            .recalculate(options: RecalculateOptions())])
            Cart.update(cartId, actions: updateActions, result: { result in
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
        if let productId = cart.value?.lineItems?[indexPath.row].productId {
            return ProductViewModel(productId: productId, size: lineItemSizeAtIndexPath(indexPath))
        }
        return nil
    }

    private func deleteLineItemAtIndexPath(_ indexPath: IndexPath) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems?[indexPath.row].id {
            self.isLoading.value = true

            var options = RemoveLineItemOptions()
            options.lineItemId = lineItemId
            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.removeLineItem(options: options),
                                                                                           .recalculate(options: RecalculateOptions())])
            Cart.update(cartId, actions: updateActions, result: { result in
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

    private func queryForActiveCart() {
        isLoading.value = true

        Cart.active(result: { result in
            if let cart = result.model, let cartId = cart.id, let version = cart.version, result.isSuccess {
                // Run recalculation before we present the refreshed cart
                Cart.update(cartId, actions: UpdateActions<CartUpdateAction>(version: version, actions: [.recalculate(options: RecalculateOptions())]), result: { result in
                    if let cart = result.model, result.isSuccess {
                        self.update(cart: cart)
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        self.update(cart: nil)
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            } else {
                // If there is no active cart, create one, with the selected product
                var cartDraft = CartDraft()
                cartDraft.currency = BaseViewModel.currencyCodeForCurrentLocale
                Cart.create(cartDraft, result: { result in
                    if let cart = result.model, result.isSuccess {
                        self.update(cart: cart)
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

        if let previousCart = previousCart, let newCart = cart, let oldLineItems = previousCart.lineItems,
                let newLineItems = newCart.lineItems {
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

        } else if let previousCart = previousCart, let lineItemsCount = previousCart.lineItems?.count, cart == nil
                && lineItemsCount > 0  {
            changeset.deletions = (0...(lineItemsCount)).map { IndexPath(row: $0, section: 0) }

        } else if let lineItemsCount = cart?.lineItems?.count, lineItemsCount > 0 {
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
        guard let cart = cart.value, let totalGrossAmount = cart.taxedPrice?.totalGross?.centAmount,
        let totalNetAmount = cart.taxedPrice?.totalNet?.centAmount else { return "" }

        return Money(currencyCode: cart.lineItems?.first?.totalPrice?.currencyCode ?? "",
                centAmount: totalGrossAmount - totalNetAmount).description
    }

    private func calculateOrderDiscount() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }
        return calculateOrderDiscount(lineItems)
    }



}
