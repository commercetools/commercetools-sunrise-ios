//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class PaymentsViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let setDefaultPaymentObserver: Signal<IndexPath, NoError>.Observer
    let deleteObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let isLoading = MutableProperty(true)

    private var creditCards: [CreditCard] = CreditCardStore.sharedInstance.creditCards
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (setDefaultPaymentSignal, setDefaultPaymentObserver) = Signal<IndexPath, NoError>.pipe()
        self.setDefaultPaymentObserver = setDefaultPaymentObserver

        let (deleteSignal, deleteObserver) = Signal<IndexPath, NoError>.pipe()
        self.deleteObserver = deleteObserver

        super.init()

        disposables += refreshSignal.observeValues { [unowned self] in
            self.creditCards = CreditCardStore.sharedInstance.creditCards
            self.isLoading.value = false
        }

        disposables += deleteSignal.observeValues { [unowned self] in
            self.creditCards.remove(at: $0.item)
            CreditCardStore.sharedInstance.creditCards = self.creditCards
            self.isLoading.value = false
        }

        disposables += setDefaultPaymentSignal.observeValues { [unowned self] in
            while let previousDefaultIndex = self.creditCards.firstIndex(where: { $0.isDefault }) {
                var previous = self.creditCards[previousDefaultIndex]
                previous.isDefault = false
                self.creditCards[previousDefaultIndex] = previous
            }
            var new = self.creditCards[$0.item]
            new.isDefault = true
            self.creditCards[$0.item] = new
            CreditCardStore.sharedInstance.creditCards = self.creditCards
            self.isLoading.value = false
        }
    }

    deinit {
        disposables.dispose()
    }

    func paymentViewModelForPayment(at indexPath: IndexPath) -> PaymentViewModel {
        return PaymentViewModel(creditCard: creditCards[indexPath.item])
    }

    // MARK: - Data Source

    var numberOfPayments: Int {
        return creditCards.count
    }

    func cardLast4Digits(at indexPath: IndexPath) -> String? {
        let fullNumber = creditCards[indexPath.item].number
        guard fullNumber.count >= 4 else { return nil }
        return String(fullNumber.suffix(from: fullNumber.index(fullNumber.endIndex, offsetBy: -4)))
    }

    func cardName(at indexPath: IndexPath) -> String {
        return creditCards[indexPath.item].name
    }

    func isPaymentDefault(at indexPath: IndexPath) -> Bool {
        return creditCards[indexPath.item].isDefault
    }
}
