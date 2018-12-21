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

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompleted()
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompleted()
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompleted()
            default:
                // make sure to complete unhandled task types
                task.setTaskCompleted()
            }
        }
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
            Order.byId(reservationId, expansion: ["lineItems[0].distributionChannel"]) { result in
                guard let reservation = result.model else { return }
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
            disposable = ProductProjectionDetailsInterfaceModel.addToCart(productId: productId, variantId: variantId).startWithCompleted {
                completionHandler()
                disposable?.dispose()
            }
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
}
