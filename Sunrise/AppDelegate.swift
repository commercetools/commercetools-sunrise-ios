//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import IQKeyboardManagerSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

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
        
        initializePushTechSDK()

        application.registerUserNotificationSettings(UIUserNotificationSettings(types: [.sound, .alert, .badge], categories: nil))
        application.registerForRemoteNotifications()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }
    
    private func initializePushTechSDK() {
#if DEBUG
        let config = PSHConfiguration(fileAtPath: Bundle.main.path(forResource: "PushTechDevConfig", ofType: "plist"))
#else
    let config = PSHConfiguration(fileAtPath: Bundle.main.path(forResource: "PushTechReleaseConfig", ofType: "plist"))
#endif
        PSHEngine.start(with: config, eventBusDelegate: nil, notificationDelegate: self)
        PSHEngine.sharedInstance().setLocationAdquisition(.always)
    }

    /**
        Provides handling for different notification actions by checking URL-like formatted parameters.

        - parameter params:                    String containing URL-like formatted parameters.
    */
    fileprivate func handleCustomActions(params: String) {
        let components = params.components(separatedBy: "=")
        if components.count == 2 {
            let key = components[0]
            let value = components[1]

            switch key {
                case "reservationId":
                    AppRouting.showReservationWithId(value)

            // As we add more notification types, appropriate cases should be placed in this switch statement.

            default:
                break
            }
        }
    }

}

extension AppDelegate: PSHNotificationDelegate {

    func shouldPerformDefaultAction(forRemoteNotification notification: PSHNotification!, completionHandler: ((UIBackgroundFetchResult) -> Void)!) -> Bool {
        if let notificationUrl = notification.campaign?.url, notification.defaultAction == .landingPage {
            AppRouting.presentNotificationWebPage(url: notificationUrl)
            return false

        } else if let extra = notification.custom?.extra {
            handleCustomActions(params: extra)
            return false
        }
        return true
    }

}

