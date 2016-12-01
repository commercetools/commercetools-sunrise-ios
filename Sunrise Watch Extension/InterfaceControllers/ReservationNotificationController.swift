//
//  ReservationNotificationController.swift
//  Sunrise
//
//  Created by Nikola Mladenovic on 12/1/16.
//  Copyright © 2016 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import Commercetools


class ReservationNotificationController: WKUserNotificationInterfaceController {

    override init() {
        // Initialize variables here.
        super.init()
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }


    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        if let orderId = notification.request.content.userInfo["reservation-id"] as? String {
            Order.byId(orderId, expansion: ["lineItems[0].distributionChannel"]) { [weak self] result in
                if let order = result.model, result.isSuccess {
                    DispatchQueue.main.async {

                        completionHandler(.custom)
                        self?.viewModel = ReservationViewModel(order: order)
                        UIView.animate(withDuration: 0.4) {
                            self?.loadingIndicator.stopAnimating()
                            self?.containerView.alpha = 1
                        }
                    }
                }
            }
        }
        // This method is called when a notification needs to be presented.
        // Implement it if you use a dynamic notification interface.
        // Populate your dynamic notification interface as quickly as possible.
        //
        // After populating your dynamic notification interface call the completion block.
        completionHandler(.custom)
    }
}
