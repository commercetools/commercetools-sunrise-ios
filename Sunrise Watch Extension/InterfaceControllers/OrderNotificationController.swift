//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import UserNotifications
import Commercetools
import ReactiveSwift

class OrderNotificationController: WKUserNotificationInterfaceController {
    

    @IBOutlet var lineItemsLabel: WKInterfaceLabel!
    @IBOutlet var firstLineItemQuantityLabel: WKInterfaceLabel!
    @IBOutlet var firstLineItemNameLabel: WKInterfaceLabel!
    @IBOutlet var moreLineItemsLabel: WKInterfaceLabel!
    @IBOutlet var orderTotalLabel: WKInterfaceLabel!
    @IBOutlet var expectedDeliveryLabel: WKInterfaceLabel?
    @IBOutlet var orderDateLabel: WKInterfaceLabel?
    
    override init() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        super.init()
    }
    
    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        if let orderId = notification.request.content.userInfo["orderId"] as? String {
            let query = """
                        {
                          me {
                            order(id: "\(orderId)") {
                              \(ReducedOrder.reducedOrderQuery)
                            }
                          }
                        }
                        """
            GraphQL.query(query) { (result: Commercetools.Result<GraphQLResponse<Me<OrderResponse>>>) in
                if let order = result.model?.data.me.order, result.isSuccess {
                    let interfaceModel = OrderDetailsInterfaceModel(order: order)
                    DispatchQueue.main.async {
                        self.lineItemsLabel.setText(interfaceModel.items)
                        self.moreLineItemsLabel.setText(interfaceModel.moreLineItems)
                        self.orderTotalLabel.setText(interfaceModel.orderTotal)
                        guard interfaceModel.numberOfLineItems > 0 else { return }
                        self.firstLineItemQuantityLabel.setText(interfaceModel.quantity(at: 0))
                        self.firstLineItemNameLabel.setText(interfaceModel.productName(at: 0))
                        self.expectedDeliveryLabel?.setText(interfaceModel.expectedDelivery)
                        self.orderDateLabel?.setText(interfaceModel.orderDate)
                        completionHandler(.custom)
                    }

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    debugPrint(errors)
                }
            }
        }
    }
}
