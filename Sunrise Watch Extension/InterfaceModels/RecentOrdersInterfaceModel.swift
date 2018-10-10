//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import ReactiveSwift
import Result
import Commercetools

class RecentOrdersInterfaceModel {
    
    // Inputs
    
    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
//    let presentOrderSignal: Signal<ProductDetailsInterfaceModel, NoError>
    
//    private let presentOrderObserver: Signal<ProductDetailsInterfaceModel, NoError>.Observer
    private var orders = [Order]()
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    init() {
        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)
        
//        (presentOrderSignal, presentOrderObserver) = Signal<ProductDetailsInterfaceModel, NoError>.pipe()
        
        retrieveRecentOrders()
    }
    
    deinit {
        disposables.dispose()
    }
    
    // MARK: - Data Source
    
    func orderNumber(at row: Int) -> String {
        return String(format: NSLocalizedString("Order # %@", comment: "Order Number"), orders[row].orderNumber ?? "—")
    }
    
    func orderDescription(at row: Int) -> String {
        let order = orders[row]
        let firstItemName = order.lineItems.first?.name.localizedString ?? ""
        return order.lineItems.count > 1 ? String(format: NSLocalizedString("%@ and %@ more", comment: "Order Summary"), firstItemName, "\(order.lineItems.count - 1)") : firstItemName
    }
    
    func orderDetailsInterfaceModel(for row: Int) -> OrderDetailsInterfaceModel {
        return OrderDetailsInterfaceModel(order: orders[row])
    }
    
    // MARK: - Wish list retrieval
    
    private func retrieveRecentOrders() {
        isLoading.value = true
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve recent orders")
        Order.query(sort: ["createdAt desc"], limit: 4) { result in
            if let orders = result.model?.results, result.isSuccess {
                DispatchQueue.main.async {
                    self.orders = orders
                    self.numberOfRows.value = orders.count
                }
                
            } else if let errors = result.errors as? [CTError], result.isFailure {
                debugPrint(errors)
                
            }
            self.isLoading.value = false
            ProcessInfo.processInfo.endActivity(activity)
        }
    }
}
