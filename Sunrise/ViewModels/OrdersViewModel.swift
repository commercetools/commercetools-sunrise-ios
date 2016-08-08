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
    let ordersExpanded = MutableProperty(false)
    let reservationsExpanded = MutableProperty(false)

    var orders = [Order]()
    var reservations = [Order]()

    private let contentChangesObserver: Observer<Changeset, NoError>

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(true)

        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (sectionExpandedSignal, expandedObserver) = Signal<Int, NoError>.pipe()
        sectionExpandedObserver = expandedObserver

        let (signal, changesObserver) = Signal<Changeset, NoError>.pipe()
        contentChangesSignal = signal
        contentChangesObserver = changesObserver

        super.init()

        refreshSignal
        .observeNext { [weak self] in
            self?.retrieveOrders(offset: 0)
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

    func orderOverviewViewModelForOrderAtIndexPath(indexPath: NSIndexPath) -> OrderOverviewViewModel {
        let orderOverviewViewModel = OrderOverviewViewModel()
        orderOverviewViewModel.order.value = indexPath.section == 0 ? orders[indexPath.row] : reservations[indexPath.row]
        return orderOverviewViewModel
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

    // MARK: - Commercetools product projections querying

    private func retrieveOrders(offset offset: UInt, text: String = "") {
        isLoading.value = true

        Commercetools.Order.query(sort: ["createdAt desc"], result: { result in
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