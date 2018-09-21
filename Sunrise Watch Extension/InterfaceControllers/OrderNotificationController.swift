//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import UserNotifications
import Commercetools
import ReactiveSwift

class OrderNotificationController: WKUserNotificationInterfaceController {
    
    @IBOutlet var orderNumberLabel: WKInterfaceLabel!
    @IBOutlet var shippingAddressLabel: WKInterfaceLabel!
    @IBOutlet var orderTotalLabel: WKInterfaceLabel!
    
    override init() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        super.init()
    }
    
    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        if let orderId = notification.request.content.userInfo["orderId"] as? String {
            Order.byId(orderId) { result in
                if let order = result.model, result.isSuccess {
                    let interfaceModel = OrderDetailsInterfaceModel(order: order)
                    DispatchQueue.main.async {
                        self.orderNumberLabel.setText(interfaceModel.orderNumber)
                        self.shippingAddressLabel.setText(interfaceModel.shippingAddress)
                        self.orderTotalLabel.setText(interfaceModel.orderTotal)
                        completionHandler(.custom)
                    }

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    debugPrint(errors)
                }
            }
        }
    }
}
