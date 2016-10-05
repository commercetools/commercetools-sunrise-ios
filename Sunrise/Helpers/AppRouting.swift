//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class AppRouting {

    private static let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)

    private static let tabBarController = UIApplication.shared.delegate?.window??.rootViewController as? UITabBarController

    /**
        In case the user is not logged in, this method presents login view controller from my account tab.
    */
    static func setupInitiallyActiveTab() {
        if let tabBarController = tabBarController, UserDefaults.standard.object(forKey: kLoggedInUsername) == nil {
            tabBarController.selectedIndex = 2
        }
    }

    /**
        In case the user is not logged in, my account tab presents login screen, or my orders otherwise.

        - parameter isLoggedIn:               Indicator whether the user is logged in.
    */
    static func setupMyAccountRootViewController(isLoggedIn: Bool) {
        guard let tabBarController = tabBarController, let controllersCount = tabBarController.viewControllers?.count,
              controllersCount > 2 else { return }

        let newAccountRootViewController: UIViewController
        if isLoggedIn {
            newAccountRootViewController = mainStoryboard.instantiateViewController(withIdentifier: "OrdersViewController")
        } else {
            newAccountRootViewController = mainStoryboard.instantiateViewController(withIdentifier: "LoginViewController")
        }

        tabBarController.viewControllers?[2] = newAccountRootViewController
    }

    /**
        Switches back to the home tab, and activates search bar as a first responder.
    */
    static func switchToSearch() {
        guard let tabBarController = tabBarController, let homeTabNavigationController = tabBarController.viewControllers?.first as? UINavigationController,
                let productOverviewViewController = homeTabNavigationController.viewControllers.first as? ProductOverviewViewController else { return }

        tabBarController.selectedIndex = 0
        homeTabNavigationController.popToRootViewController(animated: false)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(50 * Double(NSEC_PER_MSEC))) / Double(NSEC_PER_SEC)) {
            productOverviewViewController.searchController.searchBar.becomeFirstResponder()
        }
    }

    /**
        Switches back to the cart tab, and pops to root cart view controller.
    */
    static func switchToCartOverview() {
        guard let tabBarController = tabBarController, let cartNavigationController = tabBarController.viewControllers?[3] as? UINavigationController else { return }

        tabBarController.selectedIndex = 3
        cartNavigationController.popToRootViewController(animated: true)
    }

    /**
        Switches back to the home tab, and pops to root product overview view controller.
    */
    static func switchToHome() {
        guard let tabBarController = tabBarController, let homeNavigationController = tabBarController.viewControllers?.first as? UINavigationController else { return }

        tabBarController.selectedIndex = 0
        homeNavigationController.popToRootViewController(animated: true)
    }

    /**
        Switches to the account tab, and presents reservation overview view controller.
    */
    static func showReservationWithId(_ reservationId: String) {
        guard let tabBarController = tabBarController, let ordersNavigationController = tabBarController.viewControllers?[2] as? UINavigationController,
                let ordersViewController = ordersNavigationController.viewControllers.first as? OrdersViewController else { return }

        tabBarController.selectedIndex = 2
        ordersNavigationController.popToRootViewController(animated: false)
        ordersViewController.viewModel?.presentConfirmationForReservationWithId(reservationId)
    }

}
