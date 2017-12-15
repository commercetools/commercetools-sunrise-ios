//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools

class AppRouting {

    enum TabIndex: Int {
        case homeTab = 0
        case searchTab
        case categoriesTab
        case myAccountTab
        case cartTab

        var index: Int {
            return self.rawValue
        }
    }

    static let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)

    static let tabBarController = UIApplication.shared.delegate?.window??.rootViewController as? UITabBarController

    static var isLoggedIn: Bool {
        return AuthManager.sharedInstance.state == .customerToken
    }

    static var cartViewController: CartViewController? {
        return (tabBarController?.viewControllers?[TabIndex.cartTab.index] as? UINavigationController)?.viewControllers.first as? CartViewController
    }
}
