//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class ReservationsInterfaceModel {

    static let sharedInstance = ReservationsInterfaceModel()

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer

    // Outputs
    let isLoading: MutableProperty<Bool>
    let presentSignInMessage: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
    let presentReservationSignal: Signal<ReservationDetailsInterfaceModel, NoError>

    private let presentReservationObserver: Signal<ReservationDetailsInterfaceModel, NoError>.Observer
    private var reservations = [Order]()

    // MARK: - Lifecycle

    private init() {
        presentSignInMessage = MutableProperty(Commercetools.authState != .customerToken)
        isLoading = MutableProperty(false)
        numberOfRows = MutableProperty(0)

        let (presentReservationSignal, presentReservationObserver) = Signal<ReservationDetailsInterfaceModel, NoError>.pipe()
        self.presentReservationSignal = presentReservationSignal
        self.presentReservationObserver = presentReservationObserver

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver
        
        NotificationCenter.default.addObserver(self, selector: #selector(checkAuthState), name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)

        presentSignInMessage.producer
        .startWithValues({ [weak self] presentSignIn in
            if presentSignIn {
                self?.numberOfRows.value = 0
            } else {
                if self?.presentSignInMessage.value != true {
                    self?.isLoading.value = true
                    self?.retrieveReservations()
                }
            }
        })

        refreshSignal.observeValues { [weak self] in
            if self?.presentSignInMessage.value != true && self?.isLoading.value != true {
                self?.retrieveReservations()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
    }

    @objc private func checkAuthState() {
        presentSignInMessage.value = Commercetools.authState != .customerToken
    }

    // MARK: - Data Source

    func reservationName(at row: Int) -> String? {
        return reservations[row].lineItems.first?.name.localizedString
    }

    func reservationPrice(at row: Int) -> String? {
        return reservations[row].totalPrice.description
    }

    func productImageUrl(at row: Int) -> String {
        return reservations[row].lineItems.first?.variant.images?.first?.url ?? ""
    }

    func reservationDetailsInterfaceModel(for row: Int) -> ReservationDetailsInterfaceModel {
        let reservation = reservations[row]
        return ReservationDetailsInterfaceModel(reservation: reservation)
    }

    // MARK: - Presenting reservation from the notification

    func presentDetails(for reservationId: String) {
        if let reservation = reservations.filter({ $0.id == reservationId }).first {
            let detailsInterfaceModel = ReservationDetailsInterfaceModel(reservation: reservation)
            presentReservationObserver.send(value: detailsInterfaceModel)            
        }
    }

    func presentDirections(for reservationId: String) {
        if let reservation = reservations.filter({ $0.id == reservationId }).first {
            let detailsInterfaceModel = ReservationDetailsInterfaceModel(reservation: reservation)
            detailsInterfaceModel.getDirectionObserver.send(value: ())
        }
    }

    func add(reservation: Order) {
        if reservations.filter({ $0.id == reservation.id }).count == 0 {
            reservations.insert(reservation, at: 0)
            numberOfRows.value = reservations.count
        }
    }

    // MARK: - Reservations retrieval

    private func retrieveReservations() {
        guard !presentSignInMessage.value else { return }

        ProcessInfo.processInfo.performExpiringActivity(withReason: "Retrieve reservations") { [weak self] expired in
            if !expired {
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
    }
}
