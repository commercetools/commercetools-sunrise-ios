//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class BaseViewModel {

    // Outputs
    let alertMessageSignal: Signal<String, NoError>

    let alertMessageObserver: Observer<String, NoError>

    // Convenience property for obtaining currency code for user's locale
    var currencyCodeForCurrentLocale: String {
        let currencyFormatter = NSNumberFormatter()
        currencyFormatter.numberStyle = .CurrencyStyle
        currencyFormatter.locale = NSLocale.currentLocale()

        return currencyFormatter.currencyCode
    }

    // MARK: - Lifecycle

    init() {
        let (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        self.alertMessageSignal = alertMessageSignal
        self.alertMessageObserver = alertMessageObserver
    }

    func alertMessageForErrors(errors: [NSError]) -> String {
        return errors.map({
            var alertMessage = ""
            if let failureReason = $0.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                alertMessage += "\(failureReason) :"
            }
            alertMessage += $0.localizedDescription
            return alertMessage
        }).joinWithSeparator("\n")
    }

    // MARK: - Cart or order overview calculations    

    func calculateOrderDiscount(lineItems: [LineItem]) -> String {
        let totalOrderDiscountAmount = lineItems.reduce(0, combine: { $0 + calculateCartDiscountForLineItem($1) })
        return Money(currencyCode: lineItems.first?.totalPrice?.currencyCode ?? "",
                centAmount: totalOrderDiscountAmount).description
    }

    func calculateCartDiscountForLineItem(lineItem: LineItem) -> Int {
        guard let discountedPricePerQuantity = lineItem.discountedPricePerQuantity, quantity = lineItem.quantity else { return 0 }

        let discountedPriceAmount = discountedPricePerQuantity.reduce(0, combine: {
            if let quantity = $1.quantity, discountedAmount = $1.discountedPrice?.value?.centAmount {
                return $0 + quantity * discountedAmount
            }
            return $0
        })
        return discountedPriceAmount > 0 ? quantity * calculateAmountForOneLineItem(lineItem) - discountedPriceAmount : 0
    }

    func calculateSubtotal(lineItems: [LineItem]) -> String {
        var money = Money(currencyCode: lineItems.first?.totalPrice?.currencyCode ?? "")

        let subtotal = lineItems.map {
            let quantity = $0.quantity ?? 0
            let amount = calculateAmountForOneLineItem($0)
            return quantity * amount
        }.reduce(0, combine: { $0 + $1 }) ?? 0

        money.centAmount = subtotal
        return money.description
    }

    func calculateAmountForOneLineItem(lineItem: LineItem) -> Int {
        if let discountedAmount = lineItem.price?.discounted?.value?.centAmount {
            return discountedAmount

        } else if let amount = lineItem.price?.value?.centAmount {
            return amount

        } else {
            return 0
        }
    }

}