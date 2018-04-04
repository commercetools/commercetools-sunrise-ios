//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import DateToolsSwift

class MyOrdersViewModel: BaseViewModel {
    
    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    
    // Outputs
    let isLoading = MutableProperty(true)
    
    
    private var orders = [Order]()
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    override init() {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver
        
        super.init()
        
        disposables += refreshSignal.observeValues { [unowned self] in self.retrieveOrders() }
    }
    
    deinit {
        disposables.dispose()
    }

    func orderDetailsViewModelForOrder(at indexPath: IndexPath) -> OrderDetailsViewModel {
        return OrderDetailsViewModel(order: orders[indexPath.row])
    }

    // MARK: - Data Source

    var numberOfOrders: Int {
        return orders.count
    }

    func created(at indexPath: IndexPath) -> String {
        return String(format: NSLocalizedString("Created %@", comment: "Order Created Ago"), orders[indexPath.row].createdAt.timeAgoSinceNow)
    }

    func orderNumber(at indexPath: IndexPath) -> String {
        return String(format: NSLocalizedString("Order # %@", comment: "Order Number"), orders[indexPath.row].orderNumber ?? "N/A")
    }

    func totalPrice(at indexPath: IndexPath) -> String {
        return String(format: NSLocalizedString("Total %@", comment: "Order Total"), orders[indexPath.row].taxedPrice?.totalGross.description ?? orders[indexPath.row].totalPrice.description)
    }

    // MARK: - Orders retrieval
    
    private func retrieveOrders() {
        isLoading.value = true
        // TODO Add paging
        Order.query(sort: ["createdAt desc"], limit: 50) { result in
            if let orders = result.model?.results, result.isSuccess {
                self.orders = orders.filter { $0.isReservation != true }
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }
}

