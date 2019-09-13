//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import ReactiveSwift
import Result
import Commercetools

class RecentOrdersInterfaceModel {
    
    // Inputs
    let loadMoreObserver: Signal<Void, NoError>.Observer
    
    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
    let isLoadMoreHidden = MutableProperty(true)
    
    private var orders = [ReducedOrder]()
    private var totalOrders: UInt = 0
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    init() {
        let (loadMoreSignal, loadMoreObserver) = Signal<Void, NoError>.pipe()
        self.loadMoreObserver = loadMoreObserver
        
        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)
        
        disposables += loadMoreSignal
        .observeValues { [weak self] in
            self?.retrieveOrders()
        }
        
        retrieveOrders()
    }
    
    deinit {
        disposables.dispose()
    }
    
    // MARK: - Data Source
    
    func orderStatus(at row: Int) -> NSAttributedString? {
        let orderState = orders[row].orderState
        let shipmentState = orders[row].shipmentState
        let color = OrderDetailsInterfaceModel.color(for: (orderState, shipmentState))
        let status = shipmentState == .shipped ? NSLocalizedString(shipmentState!.rawValue, comment: "Shipment state") : NSLocalizedString(orderState.rawValue, comment: "Order state")
        let attributes: [NSAttributedString.Key : Any] = [.font: UIFont.preferredFont(forTextStyle: .caption2), .foregroundColor: color]
        return NSAttributedString(string: status, attributes: attributes)
    }
    
    func items(at row: Int) -> String {
        let lineItemsCount = orders[row].lineItems.count
        var items = lineItemsCount > 1 ? NSLocalizedString("Items", comment: "Items") : NSLocalizedString("Item", comment: "Item")
        items.append(" (\(lineItemsCount))")
        return items
    }
    
    func orderDescription(at row: Int) -> NSAttributedString? {
        let order = orders[row]
        let firstItemName = order.lineItems.first?.name.localizedString ?? ""
        let description = NSMutableAttributedString(string: firstItemName, attributes: [.font: UIFont.preferredFont(forTextStyle: .caption2), .foregroundColor: UIColor.white])
        if order.lineItems.count > 1 {
            description.append(NSAttributedString(string: String(format: NSLocalizedString(" + %@ more", comment: "Order Summary"), "\(order.lineItems.count - 1)"), attributes: [.font: UIFont.preferredFont(forTextStyle: .footnote), .foregroundColor: UIColor(red: 0.68, green: 0.71, blue: 0.75, alpha: 1.0)]))
        }
        return description
    }
    
    func orderTotal(at row: Int) -> String {
        return orders[row].totalPrice.description
    }
    
    func orderDetailsInterfaceModel(for row: Int) -> OrderDetailsInterfaceModel {
        return OrderDetailsInterfaceModel(order: orders[row])
    }
    
    // MARK: - Wish list retrieval
    
    private func retrieveOrders() {
        isLoading.value = true
        let limit: UInt = 5
        let offset = UInt(orders.count)
        guard offset == 0 || offset < totalOrders else { return }
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve recent orders")

        let query = """
                    {
                      me {
                        orders(where: "custom(fields(isReservation != true))", sort: ["createdAt desc"], limit: \(limit), offset: \(offset)) {
                          offset
                          count
                          total
                          results {
                            \(ReducedOrder.reducedOrderQuery)
                          }
                        }
                      }
                    }
                    """
        GraphQL.query(query) { (result: Commercetools.Result<GraphQLResponse<Me<OrdersResponse>>>) in
            if let orders = result.model?.data.me.orders.results, let total = result.model?.data.me.orders.total, let offset = result.model?.data.me.orders.offset, result.isSuccess {
                DispatchQueue.main.async {
                    guard offset == self.orders.count else { return }
                    self.orders += orders
                    self.totalOrders = total
                    self.numberOfRows.value = self.orders.count
                    self.isLoadMoreHidden.value = self.orders.count >= total
                }

            } else if let errors = result.errors as? [CTError], result.isFailure {
                debugPrint(errors)

            }
            self.isLoading.value = false
            ProcessInfo.processInfo.endActivity(activity)
        }
    }
}
