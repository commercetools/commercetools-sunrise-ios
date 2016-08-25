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

        if let notificationInfo = launchOptions?[UIApplicationLaunchOptionsRemoteNotificationKey] as? [NSObject : AnyObject] {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
                self.handlePushNotification(notificationInfo)
            }
        }

        return true
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

}

extension AppDelegate: PSHNotificationDelegate {

    func shouldPerformDefaultActionForRemoteNotification(notification: PSHNotification, completionHandler: (UIBackgroundFetchResult) -> Void) -> Bool {
        if let notificationUrl = notification.campaign?.URL where notification.defaultAction == .LandingPage {
            AppRouting.presentNotificationWebPage(notificationUrl)
            return false
        }
        return true
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        handlePushNotification(userInfo)
    }

    private func handlePushNotification(notificationInfo: [NSObject : AnyObject]) {
        if let reservationId = notificationInfo["reservation-id"] as? String {
            AppRouting.showReservationWithId(reservationId)
        }
    }

}

