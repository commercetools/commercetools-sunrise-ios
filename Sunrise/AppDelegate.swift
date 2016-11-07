//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import UserNotifications
import Commercetools
import IQKeyboardManagerSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?

    var deviceToken: String?

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

        IQKeyboardManager.sharedManager().enable = true

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { success, _ in
            if !success {
                // Requesting authorization for notifications failed. Perhaps let the API know.
            }
        }
        notificationCenter.delegate = self
        application.registerForRemoteNotifications()
        AppRouting.setupMyAccountRootViewController()

        if let notificationInfo = launchOptions?[UIApplicationLaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.handleNotification(notificationInfo: notificationInfo)
            }
        }

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
                        type.id = "b1c3dbfb-68b9-407f-ba97-e1e0ef4c2bdb"
                        type.typeId = "type"
                        options.type = type
                        options.fields = ["apnsToken": deviceToken]
                    }
                    let updateActions = UpdateActions<CustomerUpdateAction>(version: customerVersion, actions: [.setCustomType(options: options)])
                    Customer.update(actions: updateActions) { _ in }
                }
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        handleNotification(notificationInfo: response.notification.request.content.userInfo)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.alert])
    }
}
