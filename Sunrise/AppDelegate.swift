//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import IQKeyboardManagerSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
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

        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [.Sound, .Alert, .Badge], categories: nil))
        application.registerForRemoteNotifications()

        return true
    }

    func applicationDidBecomeActive(application: UIApplication) {
        application.applicationIconBadgeNumber = 0
    }
    
    private func initializePushTechSDK() {
#if DEBUG
        let config = PSHConfiguration(fileAtPath: NSBundle.mainBundle().pathForResource("PushTechDevConfig", ofType: "plist"))
#else
        let config = PSHConfiguration(fileAtPath: NSBundle.mainBundle().pathForResource("PushTechReleaseConfig", ofType: "plist"))
#endif
        PSHEngine.startWithConfiguration(config, eventBusDelegate: nil, notificationDelegate: self)
        PSHEngine.sharedInstance().setLocationAdquisition(.Always)
    }

    /**
        Provides handling for different notification actions by checking URL-like formatted parameters.

        - parameter params:                    String containing URL-like formatted parameters.
    */
    private func handleCustomActions(params: String) {
        let components = params.componentsSeparatedByString("=")
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

    func shouldPerformDefaultActionForRemoteNotification(notification: PSHNotification, completionHandler: (UIBackgroundFetchResult) -> Void) -> Bool {
        if let notificationUrl = notification.campaign?.URL where notification.defaultAction == .LandingPage {
            AppRouting.presentNotificationWebPage(notificationUrl)
            return false

        } else if let extra = notification.custom?.extra {
            handleCustomActions(extra)
            return false
        }
        return true
    }

}

