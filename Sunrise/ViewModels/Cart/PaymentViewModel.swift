//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class PaymentViewModel: BaseViewModel {

    // Inputs
    let cardNumber: MutableProperty<String?> = MutableProperty(nil)
    let name: MutableProperty<String?> = MutableProperty(nil)
    let expiryMonth: MutableProperty<String?> = MutableProperty(nil)
    let expiryYear: MutableProperty<String?> = MutableProperty(nil)
    let ccv: MutableProperty<String?> = MutableProperty(nil)
    var saveAction: Action<Void, Void, CTError>!

    // Outputs
    let title: MutableProperty<String?> = MutableProperty(nil)
    let isLoading = MutableProperty(false)
    let isStateEnabled = MutableProperty(false)
    let countries = MutableProperty([String: String]())
    let isPaymentValid = MutableProperty(false)

    var creditCard: CreditCard?

    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(creditCard: CreditCard? = nil) {
        self.creditCard = creditCard

        if creditCard == nil {
            self.title.value = NSLocalizedString("Add payment details", comment: "Add new payment")
        } else {
            self.title.value = NSLocalizedString("Edit payment details", comment: "Edit existing payment")
        }

        cardNumber.value = creditCard?.number
        name.value = creditCard?.name
        expiryMonth.value = creditCard?.validMonth
        expiryYear.value = creditCard?.validYear
        ccv.value = creditCard?.ccv

        super.init()

        disposables += isPaymentValid <~ SignalProducer.combineLatest(cardNumber.producer, name.producer, expiryMonth.producer,
                expiryYear.producer, ccv.producer).map { let (cardNumber, name, expiryMonth, expiryYear, ccv) = $0
            guard cardNumber?.count == 16 else { return false }
            var isPaymentInputValid = true
            [cardNumber, name, expiryMonth, expiryYear, ccv].forEach {
                if $0 == nil || $0?.isEmpty == true {
                    isPaymentInputValid = false
                }
            }
            return isPaymentInputValid
        }

        saveAction = Action(enabledIf: isPaymentValid) { [unowned self] _ in
            self.isLoading.value = true
            return self.savePayment()
        }
    }

    deinit {
        disposables.dispose()
    }

    private func savePayment() -> SignalProducer<Void, CTError> {
        return SignalProducer { [unowned self] observer, disposable in
            if let outdatedCardIndex = CreditCardStore.sharedInstance.creditCards.index(where: { $0.id == self.creditCard?.id }) {
                CreditCardStore.sharedInstance.creditCards.remove(at: outdatedCardIndex)
            }
            let creditCard = CreditCard(id: self.creditCard?.id ?? UUID().uuidString, name: self.name.value ?? "", number: self.cardNumber.value ?? "", ccv: self.ccv.value ?? "", validMonth: self.expiryMonth.value ?? "", validYear: self.expiryYear.value ?? "", isDefault: self.creditCard?.isDefault ?? false)
            CreditCardStore.sharedInstance.creditCards.insert(creditCard, at: 0)
            observer.sendCompleted()
        }
    }
}
