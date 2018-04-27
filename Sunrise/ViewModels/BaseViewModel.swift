//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

class BaseViewModel {

    // Outputs
    let alertMessageSignal: Signal<String, NoError>
    var isAuthenticated: Bool {
        return Commercetools.authState == .customerToken
    }

    let alertMessageObserver: Signal<String, NoError>.Observer

    // Convenience property for obtaining currency code for user's locale
    static var currencyCodeForCurrentLocale: String {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.locale = Locale.current

        return currencyFormatter.currencyCode
    }

    // Dialogue texts
    let reservationSuccessTitle = NSLocalizedString("Product has been reserved", comment: "Successful reservation")
    let reservationSuccessMessage = NSLocalizedString("You will get the notification once your product is ready for pickup", comment: "Successful reservation message")
    let reservationContinueTitle = NSLocalizedString("Continue shopping", comment: "Continue shopping")
    let oopsTitle = NSLocalizedString("Oops!", comment: "Oops!")
    let failedTitle = NSLocalizedString("Failed", comment: "Failed")
    let okAction = NSLocalizedString("OK", comment: "OK")
    let cancelAction = NSLocalizedString("Cancel", comment: "Cancel")
    let settingsAction = NSLocalizedString("Settings", comment: "Settings")

    // Cart and WishList dialogues
    let addToCartSuccessTitle = NSLocalizedString("Product added to cart", comment: "Product added to cart")
    let addToCartSuccessMessage = NSLocalizedString("Would you like to continue looking for more, or go to cart overview?", comment: "Product added to cart message")
    let continueTitle = NSLocalizedString("Continue", comment: "Continue")
    let cartOverviewTitle = NSLocalizedString("Cart overview", comment: "Cart overview")
    let couldNotAddToCartTitle = NSLocalizedString("Could not add to cart", comment: "Could not add to cart")
    let addToCartFailedTitle = NSLocalizedString("Couldn't add product to cart", comment: "Adding product to cart failed")

    // Availability texts
    let onStock = NSLocalizedString("in stock", comment: "In Stock")
    let notAvailable = NSLocalizedString("not available", comment: "Not Available")

    // Customer title options
    let titleOptions = [NSLocalizedString("MR.", comment: "MR."), NSLocalizedString("MS.", comment: "MS."),
                        NSLocalizedString("DR.", comment: "DR.")]

    // Common expansions
    let discountCodesExpansion = ["discountCodes[*].discountCode.cartDiscounts[*]"]
    let shippingMethodExpansion = ["shippingInfo.shippingMethod"]

    // MARK: - Lifecycle

    init() {
        let (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        self.alertMessageSignal = alertMessageSignal
        self.alertMessageObserver = alertMessageObserver
    }

    func alertMessage(for errors: [CTError]) -> String {
        return errors.map({ $0.errorDescription ?? "" }).joined(separator: "\n")
    }

    // MARK: - Cart overview calculations

    func calculateSubtotal(for cart: Cart?) -> String {
        guard let lineItems = cart?.lineItems else { return "" }
        return calculateSubtotal(lineItems)
    }

    func calculateTax(for cart: Cart?) -> String {
        guard let cart = cart, let totalGrossAmount = cart.taxedPrice?.totalGross.centAmount,
              let totalNetAmount = cart.taxedPrice?.totalNet.centAmount else { return "-" }

        return Money(currencyCode: cart.lineItems.first?.totalPrice.currencyCode ?? "",
                centAmount: totalGrossAmount - totalNetAmount).description
    }

    func calculateOrderDiscount(for cart: Cart?) -> String {
        guard let lineItems = cart?.lineItems else { return "" }
        return calculateOrderDiscount(lineItems)
    }

    // MARK: - Cart or order overview calculations

    func calculateOrderTotal(for cart: Cart?) -> Money? {
        guard let cart = cart else { return nil }

        if let totalGross = cart.taxedPrice?.totalGross {
            return totalGross

        } else {
            return cart.totalPrice
        }
    }

    func orderTotal(for cart: Cart?) -> String {
        if let money = calculateOrderTotal(for: cart) {
            return money.description
        }
        return ""
    }

    func shippingPrice(for cart: Cart?) -> String {
        guard let money = cart?.shippingInfo?.price else { return "-" }
        return money.centAmount == 0 ? NSLocalizedString("Free", comment: "Free shipping") : money.description
    }

    func calculateOrderDiscount(_ lineItems: [LineItem]) -> String {
        let totalOrderDiscountAmount = lineItems.reduce(0, { $0 + calculateCartDiscountForLineItem($1) })
        return totalOrderDiscountAmount > 0 ? Money(currencyCode: lineItems.first?.totalPrice.currencyCode ?? "", centAmount: totalOrderDiscountAmount).description : ""
    }

    func calculateCartDiscountForLineItem(_ lineItem: LineItem) -> Int {
        let discountedPriceAmount = lineItem.discountedPricePerQuantity.reduce(0, {
            return $0 + $1.quantity * $1.discountedPrice.value.centAmount
        })
        return discountedPriceAmount > 0 ? lineItem.quantity * calculateAmountForOneLineItem(lineItem) - discountedPriceAmount : 0
    }

    func calculateSubtotal(_ lineItems: [LineItem]) -> String {
        let subtotal = lineItems.map {
            let quantity = $0.quantity
            let amount = calculateAmountForOneLineItem($0)
            return quantity * amount
        }.reduce(0, { $0 + $1 })

        return Money(currencyCode: lineItems.first?.totalPrice.currencyCode ?? "", centAmount: subtotal).description
    }

    func calculateAmountForOneLineItem(_ lineItem: LineItem) -> Int {
        if let discountedAmount = lineItem.price.discounted?.value.centAmount {
            return discountedAmount

        } else  {
            return lineItem.price.value.centAmount
        }
    }

    func price(for lineItem: LineItem) -> String {
        if let discounted = lineItem.price.discounted?.value {
            return discounted.description

        } else if let discounted = lineItem.discountedPricePerQuantity.first?.discountedPrice.value {
            return discounted.description

        } else {
            return lineItem.price.value.description
        }
    }
}
