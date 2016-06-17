//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools

class OrdersViewController: UIViewController {

    @IBAction func logout(sender: AnyObject) {
        // Temporary perform login in view controller, refactor once orders are in place
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: kLoggedInUsername)
        NSUserDefaults.standardUserDefaults().synchronize()
        AuthManager.sharedInstance.logoutUser()
        AppRouting.setupMyAccountRootViewController(isLoggedIn: false)
    }

}