//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools

class AppRouting {

    enum TabIndex: Int {
        case homeTab = 0
        case barcodeTab
        case mainTab
        case wishlistTab
        case profileTab

        var index: Int {
            return self.rawValue
        }
    }

    static let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)

    static let tabBarController = UIApplication.shared.delegate?.window??.rootViewController as? UITabBarController

    static var isLoggedIn: Bool {
        return AuthManager.sharedInstance.state == .customerToken
    }

    static func showProductDetails(for sku: String) {
        guard let mainTabNavigationController = SunriseTabBarController.currentlyActive?.viewControllers?[TabIndex.mainTab.index] as? UINavigationController else { return }
        guard let mainViewController = mainTabNavigationController.viewControllers.first as? MainViewController else { return }
        mainTabNavigationController.popToRootViewController(animated: false)
        SunriseTabBarController.currentlyActive?.selectedIndex = TabIndex.mainTab.index
        mainViewController.viewModel?.productsViewModel.presentProductDetails(for: sku)
    }
}
