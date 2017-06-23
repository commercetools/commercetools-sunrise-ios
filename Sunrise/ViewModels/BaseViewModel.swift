//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

class BaseViewModel {

    // Outputs
    let alertMessageSignal: Signal<String, NoError>

    let alertMessageObserver: Observer<String, NoError>

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
    let settingsAction = NSLocalizedString("Settings", comment: "Settings")

    // Customer title options
    let titleOptions = [NSLocalizedString("MR.", comment: "MR."), NSLocalizedString("MRS.", comment: "MRS."),
                        NSLocalizedString("MS.", comment: "MS."), NSLocalizedString("DR.", comment: "DR.")]

    // My store
    var myStore: MutableProperty<Channel?>? {
        return AppRouting.accountViewController?.viewModel?.currentStore
    }
    // Store currently browsing
    var activeStore: MutableProperty<Channel?>? {
        return AppRouting.productOverviewViewController?.viewModel?.browsingStore
    }

    // MARK: - Lifecycle

    init() {
        let (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        self.alertMessageSignal = alertMessageSignal
        self.alertMessageObserver = alertMessageObserver
    }

    func alertMessage(for errors: [CTError]) -> String {
        return errors.map({ $0.errorDescription ?? "" }).joined(separator: "\n")
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

    func calculateOrderDiscount(_ lineItems: [LineItem]) -> String {
        let totalOrderDiscountAmount = lineItems.reduce(0, { $0 + calculateCartDiscountForLineItem($1) })
        return Money(currencyCode: lineItems.first?.totalPrice.currencyCode ?? "",
                centAmount: totalOrderDiscountAmount).description
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

}
