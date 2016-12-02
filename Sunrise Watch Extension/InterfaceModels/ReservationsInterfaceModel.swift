//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class ReservationsInterfaceModel {

    // Inputs

    // Outputs
    let isLoading: MutableProperty<Bool>
    let presentSignInMessage: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>

    private var reservations = [Order]()

    // MARK: - Lifecycle

    init() {
        presentSignInMessage = MutableProperty(Commercetools.authState != .customerToken)
        isLoading = MutableProperty(false)
        numberOfRows = MutableProperty(0)
        NotificationCenter.default.addObserver(self, selector: #selector(checkAuthState), name: Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)

        presentSignInMessage.producer
        .startWithValues({ [weak self] presentSignIn in
            if !presentSignIn {
                self?.isLoading.value = true
                self?.retrieveReservations()
            } else {
                self?.numberOfRows.value = 0
            }
        })
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
    }

    @objc private func checkAuthState() {
        presentSignInMessage.value = Commercetools.authState != .customerToken
    }

    // MARK: - Data Source

    func reservationName(at row: Int) -> String? {
        return reservations[row].lineItems?.first?.name?.localizedString
    }

    func reservationPrice(at row: Int) -> String? {
        return reservations[row].totalPrice?.description
    }

    func productImageUrl(at row: Int) -> String {
        return reservations[row].lineItems?.first?.variant?.images?.first?.url ?? ""
    }

    // MARK: - Reservations retrieval

    private func retrieveReservations() {
        Order.query(sort: ["createdAt desc"], expansion: ["lineItems[0].distributionChannel"], result: { [weak self] result in
            if let orders = result.model?.results, result.isSuccess {
                let reservations = orders.filter { $0.isReservation == true }
                self?.reservations = reservations
                self?.numberOfRows.value = reservations.count

            } else if let errors = result.errors as? [CTError], result.isFailure {
                print(errors)

            }
            self?.isLoading.value = false
        })
    }
}
