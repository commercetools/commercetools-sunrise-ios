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

        return true
    }
    
    private func initializePushTechSDK() {
#if DEBUG
        let config = PSHConfiguration(fileAtPath: NSBundle.mainBundle().pathForResource("PushTechDevConfig", ofType: "plist"))
#else
        let config = PSHConfiguration(fileAtPath: NSBundle.mainBundle().pathForResource("PushTechReleaseConfig", ofType: "plist"))
#endif
        PSHEngine.startWithConfiguration(config, eventBusDelegate: nil, notificationDelegate: nil)
        PSHEngine.sharedInstance().setLocationAdquisition(.Always)
    }

}

