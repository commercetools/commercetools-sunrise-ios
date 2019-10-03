//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import WatchKit
import Commercetools
import UserNotifications
import CoreLocation
import MapKit
import ReactiveSwift

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    var mainMenuInterfaceController: MainMenuInterfaceController? {
        return WKExtension.shared().rootInterfaceController as? MainMenuInterfaceController
    }

    private var locationManager: CLLocationManager?

    func applicationDidFinishLaunching() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.distanceFilter = 50
        locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()
        
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().addNotificationCategories()
    }

    private func presentProductDetails(productId: String) {
        guard let mainMenuInterfaceController = mainMenuInterfaceController else { return }
        mainMenuInterfaceController.popToRootController()
        DispatchQueue.main.async {
            mainMenuInterfaceController.interfaceModel?.showProductDetails(productId: productId)
        }
    }

    private func presentOrderDetails(orderId: String) {
        guard let mainMenuInterfaceController = mainMenuInterfaceController else { return }
        mainMenuInterfaceController.popToRootController()
        DispatchQueue.main.async {
            mainMenuInterfaceController.interfaceModel?.showOrderDetails(orderId: orderId)
        }
    }
}

let userLatitudeKey = "userLatitudeKey"
let userLongitudeKey = "userLongitudeKey"

extension ExtensionDelegate: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            UserDefaults.standard.set(location.coordinate.latitude, forKey: userLatitudeKey)
            UserDefaults.standard.set(location.coordinate.longitude, forKey: userLongitudeKey)
        }        
    }
}

extension ExtensionDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let reservationId = userInfo["reservation-id"] as? String, response.actionIdentifier == Notification.Action.getDirections {
            let query = """
                        {
                          me {
                            order(id: "\(reservationId)") {
                              \(ReducedReservation.reducedReservationQuery)
                            }
                          }
                        }
                        """
            GraphQL.query(query) { (result: Commercetools.Result<GraphQLResponse<Me<OrderResponse<ReducedReservation>>>>) in
                guard let reservation = result.model?.data.me.order else { return }
                let reservationInterfaceModel = ReservationDetailsInterfaceModel(reservation: reservation)
                guard let storeLocation = reservationInterfaceModel.storeLocation else { return }
                let destination = MKMapItem(placemark: MKPlacemark(coordinate: storeLocation.coordinate))
                destination.name = reservationInterfaceModel.storeName
                MKMapItem.openMaps(with: [destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                completionHandler()
            }
        } else if let productId = userInfo["productId"] as? String, response.actionIdentifier == Notification.Action.view {
            DispatchQueue.main.async {
                self.presentProductDetails(productId: productId)
                completionHandler()
            }
        } else if let orderId = userInfo["orderId"] as? String, response.actionIdentifier == Notification.Action.view {
            DispatchQueue.main.async {
                self.presentOrderDetails(orderId: orderId)
                completionHandler()
            }
        } else if let productId = userInfo["productId"] as? String, let variantIdString = userInfo["variantId"] as? String, let variantId = Int(variantIdString), response.actionIdentifier == Notification.Action.addToCart {
            var disposable: Disposable?
            disposable = ReducedProductDetailsInterfaceModel.addToCart(productId: productId, variantId: variantId).startWithCompleted {
                completionHandler()
                disposable?.dispose()
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
}
