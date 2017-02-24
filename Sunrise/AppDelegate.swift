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

    private let kProjectConfig = "ProjectConfig"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        AppRouting.setupInitiallyActiveTab()

        // Configure Commercetools SDK depending on target
#if PROD
        let configPath = "CommercetoolsProdConfig"
#else
        let configPath = "CommercetoolsStagingConfig"
#endif

        if let storedConfig = UserDefaults.standard.dictionary(forKey: kProjectConfig), let configuration = Config(config: storedConfig as NSDictionary) {
            Commercetools.config = configuration
        } else if let configuration = Config(path: configPath) {
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
            Customer.addCustomTypeIfNotExists { version, errors in
                if let version = version, errors == nil {
                    var options = SetCustomFieldOptions()
                    options.name = "apnsToken"
                    options.value = self.deviceToken
                    let updateActions = UpdateActions<CustomerUpdateAction>(version: version, actions: [.setCustomField(options: options)])

                    Customer.update(actions: updateActions) { result in
                        if result.isFailure {
                            result.errors?.forEach { debugPrint($0) }
                        }
                    }
                } else {
                    errors?.forEach { debugPrint($0) }
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
    
    // MARK: - Project configuration

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        if let queryItems = URLComponents(string: url.absoluteString)?.queryItems, url.scheme == "ctpclient", url.host == "changeProject" {
            var projectConfig = [String: Any]()
            queryItems.forEach {
                if $0.value != "true" && $0.value != "false" {
                    projectConfig[$0.name] = $0.value
                } else {
                    // Handle boolean values explicitly
                    projectConfig[$0.name] = $0.value == "true"
                }
            }
            if Config(config: projectConfig as NSDictionary) != nil {
                let alertController = UIAlertController(
                    title: "Valid Configuration",
                    message: "Confirm to store the new configuration and quit the app, or tap cancel to abort",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alertController.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
                    AppRouting.accountViewController?.viewModel?.logoutCustomer()
                    Commercetools.logoutCustomer()
                    UserDefaults.standard.set(projectConfig, forKey: self.kProjectConfig)
                    UserDefaults.standard.synchronize()
                    exit(0)
                })
                window?.rootViewController?.present(alertController, animated: true)
            } else {
                let alertController = UIAlertController(
                    title: "Invalid Configuration",
                    message: "Project has not been changed",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                window?.rootViewController?.present(alertController, animated: true)
            }
            return true
        }
        return false
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
