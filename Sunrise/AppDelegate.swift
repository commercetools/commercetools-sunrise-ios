//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import UserNotifications
import Commercetools
import CoreLocation
import IQKeyboardManagerSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?

    var deviceToken: String?

    private var locationManager: CLLocationManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        AppRouting.setupInitiallyActiveTab()

        // Configure Commercetools SDK depending on target
#if PROD
        let configPath = "CommercetoolsProdConfig"
#else
        let configPath = "CommercetoolsStagingConfig"
#endif

        if let configuration = Config(path: configPath) {
            Commercetools.config = configuration

        } else {
            // Inform user about the configuration error
        }

        locationManager = CLLocationManager()
        locationManager?.requestWhenInUseAuthorization()
        IQKeyboardManager.sharedManager().enable = true

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { success, _ in
            if !success {
                // Requesting authorization for notifications failed. Perhaps let the API know.
            }
        }
        notificationCenter.delegate = self
        application.registerForRemoteNotifications()
        addNotificationCategories()
        AppRouting.setupMyAccountRootViewController()

        return true
    }

    fileprivate func handleNotification(notificationInfo: [AnyHashable: Any]) {
        if let reservationId = notificationInfo["reservation-id"] as? String {
            AppRouting.showReservationWithId(reservationId)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        deviceToken = nil
        saveDeviceTokenForCurrentCustomer()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        self.deviceToken = deviceToken
        saveDeviceTokenForCurrentCustomer()
    }
    
    func saveDeviceTokenForCurrentCustomer() {
        if Commercetools.authState == .customerToken {
            Customer.profile { result in
                if let customerVersion = result.model?.version, result.isSuccess {
                    var options = SetCustomTypeOptions()
                    if let deviceToken = self.deviceToken {
                        var type = ResourceIdentifier()
                        type.key = "iOSUser"
                        type.typeId = "type"
                        options.type = type
                        options.fields = ["apnsToken": deviceToken]
                    }
                    let updateActions = UpdateActions<CustomerUpdateAction>(version: customerVersion, actions: [.setCustomType(options: options)])
                    Customer.update(actions: updateActions) { result in
                        if result.isFailure {
                            result.errors?.forEach { debugPrint($0) }
                        }
                    }
                } else if result.isFailure {
                    result.errors?.forEach { debugPrint($0) }
                }
            }
        }
    }

    func addNotificationCategories() {
        let viewAction = UNNotificationAction(identifier: Notification.Action.view, title: "View", options: [.authenticationRequired, .foreground])
        let getDirectionsAction = UNNotificationAction(identifier: Notification.Action.getDirections, title: "Get Directions", options: [.foreground])

        let reservationConfirmationCategory = UNNotificationCategory(identifier: Notification.Category.reservationConfirmation, actions: [viewAction, getDirectionsAction], intentIdentifiers: [], options: [])

        UNUserNotificationCenter.current().setNotificationCategories([reservationConfirmationCategory])
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.handleNotification(notificationInfo: response.notification.request.content.userInfo)
            completionHandler()
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
}
