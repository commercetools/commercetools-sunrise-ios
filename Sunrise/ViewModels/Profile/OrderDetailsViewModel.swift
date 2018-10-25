//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import DateToolsSwift
import Intents

class OrderDetailsViewModel: BaseViewModel {

    // Inputs

    // Outputs
    let orderCreated: MutableProperty<String?>
    let orderNumber: MutableProperty<String?>
    let deliveryAddress: MutableProperty<String?>
    let orderTotal: MutableProperty<String?>

    @available(iOS 12.0, *)
    var orderIntent: OrderProductIntent {
        return order.reorderIntent
    }

    private let order: Order

    // MARK: - Lifecycle

    init(order: Order) {
        self.order = order

        orderCreated = MutableProperty(String(format: NSLocalizedString("Created %@", comment: "Order Created Ago"), order.createdAt.timeAgoSinceNow))
        orderNumber = MutableProperty(String(format: NSLocalizedString("Order # %@", comment: "Order Number"), order.orderNumber ?? "N/A"))
        deliveryAddress = MutableProperty(order.shippingAddress?.description)
        orderTotal = MutableProperty(String(format: NSLocalizedString("Total %@", comment: "Order Total"), order.taxedPrice?.totalGross.description ?? order.totalPrice.description))

        super.init()
    }

    // MARK: - Data Source

    var numberOfLineItems: Int {
        return order.lineItems.count
    }

    func lineItemName(at indexPath: IndexPath) -> String {
        return order.lineItems[indexPath.row].name.localizedString ?? ""
    }

    func lineItemQuantity(at indexPath: IndexPath) -> String {
        return "x\(order.lineItems[indexPath.row].quantity)"
    }

    func lineItemPrice(at indexPath: IndexPath) -> String {
        return price(for: order.lineItems[indexPath.row])
    }
}
