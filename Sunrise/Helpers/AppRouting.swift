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
        case wishListTab
        case profileTab
        case cartTab

        var index: Int {
            return self.rawValue
        }
    }

    static let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)

    static let tabBarController = UIApplication.shared.delegate?.window??.rootViewController as? UITabBarController

    static var mainTabNavigationController: UINavigationController? = {
        return SunriseTabBarController.currentlyActive?.viewControllers?[TabIndex.mainTab.index] as? UINavigationController
    }()

    static var mainViewController: MainViewController? = {
        return mainTabNavigationController?.viewControllers.first as? MainViewController
    }()

    static var wishListViewController: WishListViewController? = {
        return SunriseTabBarController.currentlyActive?.viewControllers?[TabIndex.wishListTab.index] as? WishListViewController
    }()

    static var profileViewController: ProfileViewController? = {
        return (SunriseTabBarController.currentlyActive?.viewControllers?[TabIndex.profileTab.index] as? UINavigationController)?.viewControllers.first as? ProfileViewController
    }()

    static var cartViewController: CartViewController? = {
        return (SunriseTabBarController.currentlyActive?.viewControllers?[TabIndex.cartTab.index] as? UINavigationController)?.viewControllers.first as? CartViewController
    }()

    static var isLoggedIn: Bool {
        return AuthManager.sharedInstance.state == .customerToken
    }

    static func showMainTab() {
        mainTabNavigationController?.popToRootViewController(animated: false)
        SunriseTabBarController.currentlyActive?.selectedIndex = TabIndex.mainTab.index
    }

    static func showProductDetails(for sku: String) {
        showMainTab()
        mainViewController?.viewModel?.productsViewModel.presentProductDetails(for: sku)
    }

    static func switchToCartTab() {
        SunriseTabBarController.currentlyActive?.selectedIndex = TabIndex.cartTab.index
        SunriseTabBarController.currentlyActive?.cartButton.isSelected = true
    }
}
