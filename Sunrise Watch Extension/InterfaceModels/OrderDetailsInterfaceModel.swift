//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

class OrderDetailsInterfaceModel {
    
    // Inputs
    
    // Outputs
    var orderNumber: String {
        return String(format: NSLocalizedString("Order # %@", comment: "Order Number"), order.orderNumber ?? "—")
    }
    var orderTotal: String {
        return order.taxedPrice?.totalGross.description ?? order.totalPrice.description
    }
    var shippingAddress: String? {
        return order.shippingAddress?.description
    }
    
    private let order: Order
    
    // MARK: - Lifecycle
    
    init(order: Order) {
        self.order = order
    }
}
