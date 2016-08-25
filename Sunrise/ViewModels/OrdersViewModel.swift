//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class OrdersViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let sectionExpandedObserver: Observer<Int, NoError>

    // Outputs
    let isLoading: MutableProperty<Bool>
    let contentChangesSignal: Signal<Changeset, NoError>
    let showReservationSignal: Signal<NSIndexPath, NoError>
    let ordersExpanded = MutableProperty(false)
    let reservationsExpanded = MutableProperty(false)

    var orders = [Order]()
    var reservations = [Order]()

    private let contentChangesObserver: Observer<Changeset, NoError>
    private let showReservationObserver: Observer<NSIndexPath, NoError>

    /// The UUID of the reservation confirmation received via push notification, to be shown after next refresh.
    private var reservationConfirmationId: String? = nil

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(true)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (sectionExpandedSignal, expandedObserver) = Signal<Int, NoError>.pipe()
        sectionExpandedObserver = expandedObserver

        (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()

        (showReservationSignal, showReservationObserver) = Signal<NSIndexPath, NoError>.pipe()

        super.init()

        refreshSignal
        .observeNext { [weak self] in
            self?.retrieveOrders(offset: 0)
        }

        isLoading.signal.observeNext { [weak self] isLoading in
            if let id = self?.reservationConfirmationId, row = self?.reservations.indexOf({ $0.id == id }) where !isLoading {
                self?.showReservationObserver.sendNext(NSIndexPath(forRow: row, inSection: 1))
            }
        }

        sectionExpandedSignal
        .observeNext { [weak self] section in
            guard let strongSelf = self else { return }

            let rowsCount = section == 0 ? strongSelf.orders.count : strongSelf.reservations.count
            let rowsToModify = 0...(rowsCount > 0 ? rowsCount - 1 : 0)
            let indexPaths = rowsCount > 0 ? rowsToModify.map { NSIndexPath(forRow: $0, inSection: section) } : []

            let changeset: Changeset
            if section == 0 {
                if strongSelf.ordersExpanded.value {
                    changeset = Changeset(deletions: indexPaths)
                } else {
                    changeset = Changeset(insertions: indexPaths)
                }
                strongSelf.ordersExpanded.value = !strongSelf.ordersExpanded.value
            } else {
                if strongSelf.reservationsExpanded.value {
                    changeset = Changeset(deletions: indexPaths)
                } else {
                    changeset = Changeset(insertions: indexPaths)
                }
                strongSelf.reservationsExpanded.value = !strongSelf.reservationsExpanded.value
            }
            strongSelf.contentChangesObserver.sendNext(changeset)
        }
    }

    func orderOverviewViewModelForOrderAtIndexPath(indexPath: NSIndexPath) -> OrderOverviewViewModel? {
        if indexPath.section == 0 {
            let orderOverviewViewModel = OrderOverviewViewModel()
            orderOverviewViewModel.order.value = orders[indexPath.row]
            return orderOverviewViewModel
        }
        return nil
    }

    func reservationViewModelForOrderAtIndexPath(indexPath: NSIndexPath) -> ReservationViewModel? {
        if indexPath.section == 1 {
            return ReservationViewModel(order: reservations[indexPath.row])
        }
        return nil
    }

    // MARK: - Data Source

    func numberOfRowsInSection(section: Int) -> Int {
        if section == 0 {
            return ordersExpanded.value ? orders.count : 0
        } else {
            return reservationsExpanded.value ? reservations.count : 0
        }
    }

    func headerTitleForSection(section: Int) -> String {
        return section == 0 ? NSLocalizedString("MY ORDERS", comment: "My orders") : NSLocalizedString("MY RESERVATIONS", comment: "My reservations")
    }

    func orderNumberAtIndexPath(indexPath: NSIndexPath) -> String? {
        return indexPath.section == 0 ? orders[indexPath.row].orderNumber : reservations[indexPath.row].orderNumber
    }

    func totalPriceAtIndexPath(indexPath: NSIndexPath) -> String? {
        return indexPath.section == 0 ? orders[indexPath.row].totalPrice?.description : reservations[indexPath.row].totalPrice?.description
    }

    // MARK: - Presenting reservation confirmation from push notification

    func presentConfirmationForReservationWithId(reservationId: String) {
        if let row = reservations.indexOf({ $0.id == reservationId }) {
            showReservationObserver.sendNext(NSIndexPath(forRow: row, inSection: 1))

        } else if !isLoading.value {
            reservationConfirmationId = reservationId
            refreshObserver.sendNext()
        }
    }

    // MARK: - Commercetools product projections querying

    private func retrieveOrders(offset offset: UInt, text: String = "") {
        isLoading.value = true

        Commercetools.Order.query(sort: ["createdAt desc"], expansion: ["lineItems[0].distributionChannel"], result: { result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
            orders = Mapper<Order>().mapArray(results) where result.isSuccess {
                self.orders = orders.filter { $0.isReservation != true }
                self.reservations = orders.filter { $0.isReservation == true }

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))

            }
            self.isLoading.value = false
        })
    }



}