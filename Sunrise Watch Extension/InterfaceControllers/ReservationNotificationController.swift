//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications
import CoreLocation
import Commercetools
import ReactiveSwift
import SDWebImage

class ReservationNotificationController: WKUserNotificationInterfaceController {

//    @IBOutlet var storeMap: WKInterfaceMap!
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var titleLabel: WKInterfaceLabel!
    @IBOutlet var storeNameLabel: WKInterfaceLabel!
    @IBOutlet var distanceLabel: WKInterfaceLabel!    

    override init() {
        super.init()
        
        if let configuration = Config(path: "CommercetoolsProdConfig"), Commercetools.config == nil {
            Commercetools.config = configuration
        }
        
        distanceLabel.setText("")
    }

    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        if let reservationId = notification.request.content.userInfo["reservation-id"] as? String {
            Order.byId(reservationId, expansion: ["lineItems[0].distributionChannel"]) { [weak self] result in
                if let reservation = result.model, result.isSuccess {
                    let interfaceModel = ReservationDetailsInterfaceModel(reservation: reservation)
                    DispatchQueue.main.async {
                        self?.titleLabel.setText(interfaceModel.productName + " is ready for pickup!")
                        self?.distanceLabel.setText(interfaceModel.storeDistance)
                        self?.storeNameLabel.setText(interfaceModel.storeName)
                        if let url = URL(string: interfaceModel.productImageUrl) {
                            SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
                                if let image = image {
                                    self?.productImage.setImage(image)
                                }
                            })
                        }
//                        if let center = interfaceModel.storeLocation?.coordinate {
//                            self?.storeMap.setRegion(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
//                            self?.storeMap.addAnnotation(center, with: .red)
//                        }
                        completionHandler(.custom)
                    }
                    
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    print(errors)
                }
            }
        }
    }
}
