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

    // My store
    var myStore: MutableProperty<Channel?>? {
        return AppRouting.accountViewController?.viewModel?.currentStore
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

    func calculateOrderDiscount(_ lineItems: [LineItem]) -> String {
        let totalOrderDiscountAmount = lineItems.reduce(0, { $0 + calculateCartDiscountForLineItem($1) })
        return Money(currencyCode: lineItems.first?.totalPrice?.currencyCode ?? "",
                centAmount: totalOrderDiscountAmount).description
    }

    func calculateCartDiscountForLineItem(_ lineItem: LineItem) -> Int {
        guard let discountedPricePerQuantity = lineItem.discountedPricePerQuantity, let quantity = lineItem.quantity else { return 0 }

        let discountedPriceAmount = discountedPricePerQuantity.reduce(0, {
            if let quantity = $1.quantity, let discountedAmount = $1.discountedPrice?.value?.centAmount {
                return $0 + quantity * discountedAmount
            }
            return $0
        })
        return discountedPriceAmount > 0 ? quantity * calculateAmountForOneLineItem(lineItem) - discountedPriceAmount : 0
    }

    func calculateSubtotal(_ lineItems: [LineItem]) -> String {
        var money = Money(currencyCode: lineItems.first?.totalPrice?.currencyCode ?? "")

        let subtotal = lineItems.map {
            let quantity = $0.quantity ?? 0
            let amount = calculateAmountForOneLineItem($0)
            return quantity * amount
        }.reduce(0, { $0 + $1 })

        money.centAmount = subtotal
        return money.description
    }

    func calculateAmountForOneLineItem(_ lineItem: LineItem) -> Int {
        if let discountedAmount = lineItem.price?.discounted?.value?.centAmount {
            return discountedAmount

        } else if let amount = lineItem.price?.value?.centAmount {
            return amount

        } else {
            return 0
        }
    }

}
