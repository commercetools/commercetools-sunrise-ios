//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let deleteLineItemObserver: Observer<NSIndexPath, NoError>

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

    let cart: MutableProperty<Cart?>

    private let contentChangesObserver: Observer<Changeset, NoError>
    private let deleteLineItemSignal: Signal<NSIndexPath, NoError>

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(false)
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        let (deleteLineItemSignal, deleteLineItemObserver) = Signal<NSIndexPath, NoError>.pipe()
        self.deleteLineItemSignal = deleteLineItemSignal
        self.deleteLineItemObserver = deleteLineItemObserver

        cart = MutableProperty(nil)
        numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems?.count ?? 0) }

        super.init()

        subtotal <~ cart.producer.map { [unowned self] _ in self.calculateSubtotal() }
        orderTotal <~ cart.producer.map { [unowned self] _ in self.calculateOrderTotal() }
        tax <~ cart.producer.map { [unowned self] _ in self.calculateTax() }
        taxRowHidden <~ tax.producer.map { tax in tax == "" }
        orderDiscount <~ cart.producer.map { [unowned self] _ in self.calculateOrderDiscount() }

        refreshSignal.observeNext { [weak self] in
            self?.queryForActiveCart()
        }

        deleteLineItemSignal.observeNext { [weak self] indexPath in
            self?.deleteLineItemAtIndexPath(indexPath)
        }
    }

    // MARK: - Data Source

    func numberOfRowsInSection(section: Int) -> Int {
        if let lineItemsCount = cart.value?.lineItems?.count where lineItemsCount > 0 {
            return lineItemsCount + 1
        } else {
            return 0
        }
    }

    func canDeleteRowAtIndexPath(indexPath: NSIndexPath) -> Bool {
        return indexPath.row != numberOfRowsInSection(0) - 1
    }

    func lineItemNameAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].name?.localizedString ?? ""
    }

    func lineItemSkuAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.sku ?? ""
    }

    func lineItemSizeAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.attributes?.filter({ $0.name == "size" }).first?.value as? String ?? "N/A"
    }

    func lineItemImageUrlAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.images?.first?.url ?? ""
    }

    func lineItemOldPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = cart.value?.lineItems?[indexPath.row].price, value = price.value,
        _ = price.discounted?.value else { return "" }

        return value.description
    }

    func lineItemPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = cart.value?.lineItems?[indexPath.row].price, value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    func lineItemQuantityAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].quantity?.description ?? "0"
    }

    func lineItemTotalPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].totalPrice?.description ?? "N/A"
    }

    func updateLineItemQuantityAtIndexPath(indexPath: NSIndexPath, quantity: String) {
        if let cartId = cart.value?.id, version = cart.value?.version, lineItemId = cart.value?.lineItems?[indexPath.row].id,
                quantity = UInt(quantity) {
            self.isLoading.value = true
            Commercetools.Cart.update(cartId, version: version, actions: [["action": "changeLineItemQuantity",
                                                                           "lineItemId": lineItemId,
                                                                           "quantity": quantity],
                                                                          ["action": "recalculate"]], result: { result in
                if let cart = Mapper<Cart>().map(result.response) where result.isSuccess {
                    self.updateCart(cart)
                } else if let errors = result.errors where result.isFailure {
                    self.updateCart(nil)
                    super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                }
                self.isLoading.value = false
            })
        }
    }

    func productDetailsViewModelForLineItemAtIndexPath(indexPath: NSIndexPath) -> ProductViewModel? {
        if let productId = cart.value?.lineItems?[indexPath.row].productId {
            return ProductViewModel(productId: productId, size: lineItemSizeAtIndexPath(indexPath))
        }
        return nil
    }

    private func deleteLineItemAtIndexPath(indexPath: NSIndexPath) {
        if let cartId = cart.value?.id, version = cart.value?.version, lineItemId = cart.value?.lineItems?[indexPath.row].id {
            self.isLoading.value = true
            Commercetools.Cart.update(cartId, version: version, actions: [["action": "removeLineItem",
                                                                           "lineItemId": lineItemId],
                                                                          ["action": "recalculate"]], result: { result in
                if let cart = Mapper<Cart>().map(result.response) where result.isSuccess {
                    self.updateCart(cart)
                } else if let errors = result.errors where result.isFailure {
                    self.updateCart(nil)
                    super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                }
                self.isLoading.value = false
            })
        }
    }

    // MARK: - Cart retrieval

    private func queryForActiveCart() {
        isLoading.value = true

        // Get the cart with state Active which has the most recent lastModifiedAt.
        Commercetools.Cart.query(predicates: ["cartState=\"Active\""], sort: ["lastModifiedAt desc"], limit: 1,
                result: { result in
                    if let results = result.response?["results"] as? [[String: AnyObject]],
                            carts = Mapper<Cart>().mapArray(results), cartId = carts.first?.id,
                            version = carts.first?.version where result.isSuccess {
                        // Run recalculation before we present the refreshed cart
                        Commercetools.Cart.update(cartId, version: version, actions: [["action": "recalculate"]], result: { result in
                            if let cart = Mapper<Cart>().map(result.response) where result.isSuccess {
                                self.updateCart(cart)
                            } else if let errors = result.errors where result.isFailure {
                                self.updateCart(nil)
                                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                            }
                            self.isLoading.value = false
                        })
                    } else if let errors = result.errors where result.isFailure {
                        self.updateCart(nil)
                        super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                        self.isLoading.value = false
                    } else {
                        // If there is no active cart, create one, with the selected product
                        Commercetools.Cart.create(["currency": self.currencyCodeForCurrentLocale], result: { result in
                            if let cart = Mapper<Cart>().map(result.response) where result.isSuccess {
                                self.updateCart(cart)
                            } else if let errors = result.errors where result.isFailure {
                                self.updateCart(nil)
                                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                            }
                            self.isLoading.value = false
                        })
                    }
                })
    }

    private func updateCart(cart: Cart?) {
        let previousCart = self.cart.value

        var changeset = Changeset()

        if let previousCart = previousCart, newCart = cart, oldLineItems = previousCart.lineItems,
                newLineItems = newCart.lineItems {
            var deletions = [NSIndexPath]()
            var modifications = [NSIndexPath]()
            for (i, lineItem) in oldLineItems.enumerate() {
                if !newLineItems.contains(lineItem) {
                    deletions.append(NSIndexPath(forRow: i, inSection:0))
                } else {
                    modifications.append(NSIndexPath(forRow: i, inSection:0))
                }
            }

            if newLineItems.count > 0 && oldLineItems.count > 0 {
                modifications.append(NSIndexPath(forRow: oldLineItems.count, inSection:0))
            }
            changeset.modifications = modifications
            if newLineItems.count == 0 && oldLineItems.count > 0 {
                deletions.append(NSIndexPath(forRow: oldLineItems.count, inSection:0))
            }
            changeset.deletions = deletions

            var insertions = [NSIndexPath]()
            for (i, lineItem) in newLineItems.enumerate() {
                if !oldLineItems.contains(lineItem) {
                    insertions.append(NSIndexPath(forRow: i, inSection:0))
                }
            }
            if oldLineItems.count == 0 && newLineItems.count > 0 {
                insertions.append(NSIndexPath(forRow: newLineItems.count, inSection:0))
            }
            changeset.insertions = insertions

        } else if let previousCart = previousCart, lineItemsCount = previousCart.lineItems?.count where cart == nil
                && lineItemsCount > 0  {
            changeset.deletions = (0...(lineItemsCount)).map { NSIndexPath(forRow: $0, inSection: 0) }

        } else if let lineItemsCount = cart?.lineItems?.count where lineItemsCount > 0 {
            changeset.insertions = (0...lineItemsCount).map { NSIndexPath(forRow: $0, inSection: 0) }
        }

        self.cart.value = cart
        contentChangesObserver.sendNext(changeset)


    }
    
    // MARK: - Cart overview calculations
    
    private func calculateOrderTotal() -> String {
        guard let cart = cart.value, totalPrice = cart.totalPrice else { return "" }
        
        if let totalGross = cart.taxedPrice?.totalGross {
            return totalGross.description
            
        } else {
            return totalPrice.description
        }
    }

    private func calculateSubtotal() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }
        return calculateSubtotal(lineItems)
    }

    private func calculateTax() -> String {
        guard let cart = cart.value, totalGrossAmount = cart.taxedPrice?.totalGross?.centAmount,
        totalNetAmount = cart.taxedPrice?.totalNet?.centAmount else { return "" }

        return Money(currencyCode: cart.lineItems?.first?.totalPrice?.currencyCode ?? "",
                centAmount: totalGrossAmount - totalNetAmount).description
    }

    private func calculateOrderDiscount() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }
        return calculateOrderDiscount(lineItems)
    }



}