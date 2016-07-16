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
        PSHEngine.initializeWithAppId("5786c12785216d3ab8000045", appSecret: "1e9898f4f8722cfcae67e45bd96849f6", notificationDelegate: nil, eventBusDelegate: nil, logLevel: .Debug)
#else
        PSHEngine.initializeWithAppId("5786c0ab85216d031b00004b", appSecret: "b2560ca0865d797013615d232bbe5991", notificationDelegate: nil, eventBusDelegate: nil, logLevel: .Error)
#endif
    }

}

