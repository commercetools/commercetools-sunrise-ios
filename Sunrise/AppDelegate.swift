//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import UserNotifications
import Commercetools
import CoreLocation
import AVFoundation
import IQKeyboardManagerSwift
import AWSS3

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static var shared: AppDelegate {
        return UIApplication.shared.delegate as! AppDelegate
    }

    var window: UIWindow?

    private static var deviceToken: String?

    private var locationManager: CLLocationManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        if let configuration = Project.config {
            Commercetools.config = configuration

        } else {
            // Inform user about the configuration error
        }

        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: AWSRegionType.EUWest1, identityPoolId: "eu-west-1:f0aa3646-d97e-4ee1-a102-6ff671bf089d")
        let configuration = AWSServiceConfiguration(region: AWSRegionType.EUWest1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration

        locationManager = CLLocationManager()
        locationManager?.requestWhenInUseAuthorization()
        IQKeyboardManager.shared.enable = true

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.requestAuthorization(options: [.badge, .alert, .sound]) { success, _ in
            if !success {
                // Requesting authorization for notifications failed. Perhaps let the API know.
            }
        }
        notificationCenter.delegate = self
        application.registerForRemoteNotifications()
        addNotificationCategories()

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Swift.Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            let pathComponents = url.pathComponents
            // POP (e.g https://demo.commercetools.com/en/search?q=jeans)
            if let indexOfSearch = pathComponents.index(of: "search"), let urlComponents = URLComponents(string: url.absoluteString),
               let queryItems = urlComponents.queryItems, let query = queryItems["q"].first, indexOfSearch > 0 {
                AppRouting.search(query: query, filters: queryItems)
                return true

            // PDP (e.g https://demo.commercetools.com/en/brunello-cucinelli-coat-mf9284762-cream-M0E20000000DQR5.html)
            } else if let sku = pathComponents.last?.components(separatedBy: "-").last, sku.count > 5, sku.contains(".html") {
                AppRouting.showProductDetails(for: String(sku[...String.Index(encodedOffset: sku.count - 6)]))
                return true

            // Orders (e.g https://demo.commercetools.com/en/user/orders)
            } else if pathComponents.last?.contains("orders") == true {
                AppRouting.showMyOrders()
                return true

            // Order details (e.g https://demo.commercetools.com/en/user/orders/87896195?)
            } else if pathComponents.contains("orders"), let orderNumber = pathComponents.last, !orderNumber.contains("orders") {
                AppRouting.showOrderDetails(for: orderNumber)

            // Category overview (e.g https://demo.commercetools.com/en/women-clothing-blazer)
            } else if pathComponents.count == 3, pathComponents[1].count == 2 {
                AppRouting.showCategory(locale: pathComponents[1], slug: pathComponents[2])
            }
        } else if userActivity.activityType == "com.commercetools.Sunrise.viewProductDetails", let sku = userActivity.userInfo?["sku"] as? String {
            AppRouting.showProductDetails(for: sku)
        }
        return false
    }

    fileprivate func handleNotification(notificationInfo: [AnyHashable: Any]) {
        if let reservationId = notificationInfo["reservation-id"] as? String {
            AppRouting.showReservationDetails(for: reservationId)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        AppDelegate.deviceToken = nil
        AppDelegate.saveDeviceTokenForCurrentCustomer()
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let deviceToken = deviceToken.reduce("", {$0 + String(format: "%02X", $1)})
        AppDelegate.deviceToken = deviceToken
        AppDelegate.saveDeviceTokenForCurrentCustomer()
    }
    
    static func saveDeviceTokenForCurrentCustomer() {
        if Commercetools.authState == .customerToken {
            Customer.addCustomTypeIfNotExists { version, errors in
                if let version = version, let deviceToken = self.deviceToken, errors == nil {
                    let updateActions = UpdateActions(version: version, actions: [CustomerUpdateAction.setCustomField(name: "apnsToken", value: .string(value: deviceToken))])

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
        let viewAction = UNNotificationAction(identifier: Notification.Action.view, title: NSLocalizedString("View", comment: "View"), options: [.authenticationRequired, .foreground])
        let getDirectionsAction = UNNotificationAction(identifier: Notification.Action.getDirections, title: NSLocalizedString("Get Directions", comment: "Get Directions"), options: [.foreground])

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

extension AppDelegate: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
    }
}
