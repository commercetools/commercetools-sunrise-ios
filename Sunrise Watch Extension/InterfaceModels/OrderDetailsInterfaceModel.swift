//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import ReactiveSwift
import Result
import Commercetools

class OrderDetailsInterfaceModel {
    
    // Inputs
    
    // Outputs
    var orderNumber: String {
        return order.orderNumber ?? "—"
    }
    var orderTotal: String {
        return order.taxedPrice?.totalGross.description ?? order.totalPrice.description
    }
    var shippingAddress: String? {
        return order.shippingAddress?.description
    }
    var numberOfLineItems: Int {
        return order.lineItems.count
    }
    var items: String {
        let lineItemsCount = order.lineItems.count
        var items = lineItemsCount > 1 ? NSLocalizedString("Items", comment: "Items") : NSLocalizedString("Item", comment: "Item")
        items.append(" (\(lineItemsCount))")
        return items
    }
    var userActivityInfo: [AnyHashable: Any]? {
        return ["id": order.id]
    }
    let orderStatus: NSAttributedString
    let expectedDelivery: String
    let orderDate: String
    let moreLineItems: String
    
    private let dateFormatter = DateFormatter()
    private let order: ReducedOrder
    
    // MARK: - Lifecycle
    
    init(order: ReducedOrder) {
        self.order = order
        dateFormatter.dateFormat = "EEE, MMM dd"
        expectedDelivery = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: 2, to: Date())!)
        orderDate = dateFormatter.string(from: Date())
        
        let status = order.shipmentState == .shipped ? NSLocalizedString(order.shipmentState!.rawValue, comment: "Shipment state") : NSLocalizedString(order.orderState.rawValue, comment: "Order state")
        let attributes: [NSAttributedString.Key : Any] = [.foregroundColor: OrderDetailsInterfaceModel.color(for: (order.orderState, order.shipmentState))]
        orderStatus = NSAttributedString(string: status, attributes: attributes)
        moreLineItems = order.lineItems.count > 1 ? String(format: NSLocalizedString("and %@ more", comment: "Order Summary"), "\(order.lineItems.count - 1)") : ""
    }
    
    // MARK: - Data Source
    
    func quantity(at row: Int) -> String {
        return "x\(order.lineItems[row].quantity)"
    }
    
    func productName(at row: Int) -> String? {
        return order.lineItems[row].name.localizedString
    }
    
    // MARK: - Order status colors
    
    static func color(for statuses: (OrderState, ShipmentState?)) -> UIColor {
        switch (statuses.0, statuses.1) {
            case (_, .shipped?):
                return UIColor(red: 0.48, green: 0.76, blue: 0.17, alpha: 1.0)
            case (.open, _):
                return .white
            case (.confirmed, _):
                return UIColor(red: 0.00, green: 0.62, blue: 1.00, alpha: 1.0)
            case (.cancelled, _):
                return UIColor(red: 0.94, green: 0.39, blue: 0.25, alpha: 1.0)
            default:
                return UIColor(red: 0.48, green: 0.76, blue: 0.17, alpha: 1.0)
        }
    }
}
