//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import CoreLocation
import DateToolsSwift

class MyReservationsViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let pendingReservationDetailsId = MutableProperty<String?>(nil)

    // Outputs
    let isLoading = MutableProperty(true)
    let showReservationDetailsSignal: Signal<IndexPath, NoError>

    private let showReservationDetailsObserver: Signal<IndexPath, NoError>.Observer
    private var reservations = [Order]()
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        (showReservationDetailsSignal, showReservationDetailsObserver) = Signal<IndexPath, NoError>.pipe()

        super.init()

        disposables += refreshSignal.observeValues { [unowned self] in self.retrieveReservations() }
    }

    deinit {
        disposables.dispose()
    }

    func reservationDetailsViewModelForOrder(at indexPath: IndexPath) -> ReservationDetailsViewModel {
        return ReservationDetailsViewModel(reservation: reservations[indexPath.row])
    }

    // MARK: - Data Source

    var numberOfReservations: Int {
        return reservations.count
    }

    func reservationDate(at indexPath: IndexPath) -> String {
        return reservations[indexPath.row].createdAt.timeAgoSinceNow
    }

    func imageUrl(at indexPath: IndexPath) -> String {
        return reservations[indexPath.row].lineItems.first?.variant.images?.first?.url ?? ""
    }

    func productName(at indexPath: IndexPath) -> String? {
        return reservations[indexPath.row].lineItems.first?.name.localizedString
    }

    func totalPrice(at indexPath: IndexPath) -> String {
        return String(format: NSLocalizedString("Total %@", comment: "Order Total"), reservations[indexPath.row].taxedPrice?.totalGross.description ?? reservations[indexPath.row].totalPrice.description)
    }

    // MARK: - Reservations retrieval

    private func retrieveReservations() {
        isLoading.value = true
        // TODO Add paging
        Order.query(sort: ["createdAt desc"], expansion: ["lineItems[0].distributionChannel"], limit: 50) { result in
            if let orders = result.model?.results, result.isSuccess {
                self.reservations = orders.filter { $0.isReservation == true }
                self.isLoading.value = false

                if let pendingRow = self.reservations.index(where: { $0.id == self.pendingReservationDetailsId.value }) {
                    self.pendingReservationDetailsId.value = nil
                    self.showReservationDetailsObserver.send(value: IndexPath(row: pendingRow, section: 0))
                }

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }
}

