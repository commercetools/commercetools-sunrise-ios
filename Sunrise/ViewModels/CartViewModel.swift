//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>

    // Outputs
    let isLoading: MutableProperty<Bool>
    let taxRowHidden = MutableProperty(false)
    let numberOfItems = MutableProperty("")
    let subtotal = MutableProperty("")
    let orderDiscount = MutableProperty("")
    let tax = MutableProperty("")
    let orderTotal = MutableProperty("")

    let cart: MutableProperty<Cart?>

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(false)
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        cart = MutableProperty(nil)
        numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems?.count ?? 0) }

        super.init()

        subtotal <~ cart.producer.map { [unowned self] _ in self.calculateSubtotal() }
        orderTotal <~ cart.producer.map { [unowned self] _ in self.calculateOrderTotal() }
        tax <~ cart.producer.map { [unowned self] _ in self.calculateTax() }
        taxRowHidden <~ tax.producer.map { tax in tax == "" }
        orderDiscount <~ cart.producer.map { [unowned self] _ in self.calculateOrderDiscount() }

        refreshSignal
        .observeNext { [weak self] in
            self?.queryForActiveCart()
        }
    }

    // MARK: - Data Source

    func numberOfRowsInSection(section: Int) -> Int {
        if let lineItemsCount = cart.value?.lineItems?.count {
            return lineItemsCount + 1
        } else {
            return 0
        }
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

    // MARK: - Commercetools product projections querying

    private func queryForActiveCart() {
        isLoading.value = true

        // Get the cart with state Active which has the most recent lastModifiedAt.
        Commercetools.Cart.query(predicates: ["cartState=\"Active\""], sort: ["lastModifiedAt desc"], limit: 1,
                result: { result in
                    if let results = result.response?["results"] as? [[String: AnyObject]],
                    carts = Mapper<Cart>().mapArray(results) where result.isSuccess {
                        self.cart.value = carts.first

                    } else if let errors = result.errors where result.isFailure {
                        super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))

                    }
                    self.isLoading.value = false
                })
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

    private func calculateOrderDiscount() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }

        let totalOrderDiscountAmount = lineItems.reduce(0, combine: { $0 + calculateCartDiscountForLineItem($1) })
        return Money(currencyCode: lineItems.first?.totalPrice?.currencyCode ?? "",
                     centAmount: totalOrderDiscountAmount).description

    }

    private func calculateCartDiscountForLineItem(lineItem: LineItem) -> Int {
        guard let discountedPricePerQuantity = lineItem.discountedPricePerQuantity, quantity = lineItem.quantity else { return 0 }

        let discountedAmount = discountedPricePerQuantity.reduce(0, combine: {
            if let quantity = $1.quantity, discountedAmount = $1.discountedPrice?.value?.centAmount {
                return $0 + quantity * discountedAmount
            }
            return $0
        })
        return discountedAmount > 0 ? quantity * calculateAmountForOneLineItem(lineItem) - discountedAmount : 0
    }

    private func calculateTax() -> String {
        guard let cart = cart.value, totalGrossAmount = cart.taxedPrice?.totalGross?.centAmount,
        totalNetAmount = cart.taxedPrice?.totalNet?.centAmount else { return "" }

        return Money(currencyCode: cart.lineItems?.first?.totalPrice?.currencyCode ?? "",
                     centAmount: totalGrossAmount - totalNetAmount).description
    }

    private func calculateSubtotal() -> String {
        guard let lineItems = cart.value?.lineItems else { return "" }

        var money = Money(currencyCode: lineItems.first?.totalPrice?.currencyCode ?? "")

        let subtotal = lineItems.map {
            let quantity = $0.quantity ?? 0
            let amount = calculateAmountForOneLineItem($0)
            return quantity * amount
        }.reduce(0, combine: { $0 + $1 }) ?? 0

        money.centAmount = subtotal
        return money.description
    }

    private func calculateAmountForOneLineItem(lineItem: LineItem) -> Int {
        if let discountedAmount = lineItem.price?.discounted?.value?.centAmount {
            return discountedAmount

        } else if let amount = lineItem.price?.value?.centAmount {
            return amount

        } else {
            return 0
        }
    }
}