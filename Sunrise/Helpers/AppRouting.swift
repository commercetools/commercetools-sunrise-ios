//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class AppRouting {

    private static let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)

    private static let tabBarController = UIApplication.sharedApplication().delegate?.window??.rootViewController as? UITabBarController

    /**
        In case the user is not logged in, this method presents login view controller from my account tab.
    */
    static func setupInitiallyActiveTab() {
        if let tabBarController = tabBarController where NSUserDefaults.standardUserDefaults().objectForKey(kLoggedInUsername) == nil {
            tabBarController.selectedIndex = 2
        }
    }

    /**
        In case the user is not logged in, my account tab presents login screen, or my orders otherwise.

        - parameter isLoggedIn:               Indicator whether the user is logged in.
    */
    static func setupMyAccountRootViewController(isLoggedIn isLoggedIn: Bool) {
        guard let tabBarController = tabBarController where tabBarController.viewControllers?.count > 2 else { return }

        let newAccountRootViewController: UIViewController
        if isLoggedIn {
            newAccountRootViewController = mainStoryboard.instantiateViewControllerWithIdentifier("OrdersViewController")
        } else {
            newAccountRootViewController = mainStoryboard.instantiateViewControllerWithIdentifier("LoginViewController")
        }

        tabBarController.viewControllers?[2] = newAccountRootViewController
    }

    /**
        Switches back to the home tab, and activates search bar as a first responder.
    */
    static func switchToSearch() {
        guard let tabBarController = tabBarController, homeTabNavigationController = tabBarController.viewControllers?.first as? UINavigationController,
                productOverviewViewController = homeTabNavigationController.viewControllers.first as? ProductOverviewViewController else { return }

        tabBarController.selectedIndex = 0
        homeTabNavigationController.popToRootViewControllerAnimated(false)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(50 * Double(NSEC_PER_MSEC))), dispatch_get_main_queue()) {
            productOverviewViewController.searchController.searchBar.becomeFirstResponder()
        }
    }

    /**
        Switches back to the cart tab, and pops to root cart view controller.
    */
    static func switchToCartOverview() {
        guard let tabBarController = tabBarController, cartNavigationController = tabBarController.viewControllers?[3] as? UINavigationController else { return }

        tabBarController.selectedIndex = 3
        cartNavigationController.popToRootViewControllerAnimated(true)
    }

    /**
        Switches back to the home tab, and pops to root product overview view controller.
    */
    static func switchToHome() {
        guard let tabBarController = tabBarController, homeNavigationController = tabBarController.viewControllers?.first as? UINavigationController else { return }

        tabBarController.selectedIndex = 0
        homeNavigationController.popToRootViewControllerAnimated(true)
    }

    /**
        Switches to the account tab, and presents reservation overview view controller.
    */
    static func showReservationWithId(reservationId: String) {
        guard let tabBarController = tabBarController, ordersNavigationController = tabBarController.viewControllers?[2] as? UINavigationController,
                ordersViewController = ordersNavigationController.viewControllers.first as? OrdersViewController else { return }

        tabBarController.selectedIndex = 2
        ordersNavigationController.popToRootViewControllerAnimated(false)
        ordersViewController.viewModel?.presentConfirmationForReservationWithId(reservationId)
    }

}
