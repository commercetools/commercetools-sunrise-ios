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

    /// Tab index to present on successful login.
    private static var tabIndexAfterLogIn: Int? = nil

    static var isLoggedIn: Bool {
        return AuthManager.sharedInstance.state == .customerToken
    }

    static var cartViewController: CartViewController? {
        return (tabBarController?.viewControllers?[TabIndex.cartTab.index] as? UINavigationController)?.viewControllers.first as? CartViewController
    }

    static var accountViewController: AccountViewController? {
        return (tabBarController?.viewControllers?[TabIndex.myAccountTab.index] as? UINavigationController)?.viewControllers.first as? AccountViewController
    }

    static var productOverviewViewController: ProductOverviewViewController? {
        return (tabBarController?.viewControllers?[TabIndex.homeTab.index] as? UINavigationController)?.viewControllers.first as? ProductOverviewViewController
    }

    static var categoryProductOverviewViewController: ProductOverviewViewController? {
        if let categoriesNavigationController = tabBarController?.viewControllers?[TabIndex.categoriesTab.index] as? UINavigationController {
            return categoriesNavigationController.viewControllers.count > 1 ? categoriesNavigationController.viewControllers[1] as? ProductOverviewViewController : nil
        }
        return nil
    }

    /**
        In case the user is not logged in, this method presents login view controller from my account tab.
    */
    static func setupInitiallyActiveTab() {
        if let tabBarController = tabBarController, UserDefaults.standard.object(forKey: kLoggedInUsername) == nil {
            tabBarController.selectedIndex = TabIndex.myAccountTab.index
        }
    }

    /**
        Activates my account tab which contains sign in view controller.

        - parameter tabIndexAfterLogIn:       Optional parameter, indicating which tab should become active after successful login.
    */
    static func presentSignInViewController(tabIndexAfterLogIn: Int? = nil) {
        self.tabIndexAfterLogIn = tabIndexAfterLogIn
        tabBarController?.selectedIndex = TabIndex.myAccountTab.index
    }

    /**
        In case the user is not logged in, my account tab presents login screen, or my orders otherwise.
    */
    static func setupMyAccountRootViewController() {
        guard let tabBarController = tabBarController, let controllersCount = tabBarController.viewControllers?.count,
              controllersCount > TabIndex.myAccountTab.index else { return }

        let newAccountRootViewController: UIViewController
        if isLoggedIn {
            newAccountRootViewController = mainStoryboard.instantiateViewController(withIdentifier: "AccountViewController")
            if let navigationController = newAccountRootViewController as? UINavigationController,
               let accountViewController = navigationController.viewControllers.first as? AccountViewController {
                // Preload orders
                _ = accountViewController.view
            }
        } else {
            newAccountRootViewController = mainStoryboard.instantiateViewController(withIdentifier: "LoginViewController")
        }

        tabBarController.viewControllers?[TabIndex.myAccountTab.index] = newAccountRootViewController
    }

    /**
        Switches to the previously specified tab, after login.
    */
    static func switchAfterLogInSuccess() {
        if let tabIndex = tabIndexAfterLogIn, let tabBarController = tabBarController {
            tabBarController.selectedIndex = tabIndex
            tabIndexAfterLogIn = nil
            DispatchQueue.main.async {
                setupMyAccountRootViewController()
            }
        } else {
            setupMyAccountRootViewController()
        }
    }

    /**
        Switches back to the home tab, and activates search bar as a first responder.

        - parameter query:                   Optional parameter, if specified, used for populating the search field.
    */
    static func switchToSearch(query: String = "") {
        switchToHome()
        productOverviewViewController?.searchController.searchBar.text = query
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.05) {
            productOverviewViewController?.searchController.searchBar.becomeFirstResponder()
        }
    }

    /**
        Switches to the cart tab, and adds the specified product, and applies discount code if specified.

        - parameter product:               The ID of the product to be added.
        - parameter variantId:             The product variant which should be added to the cart.
        - parameter quantity:              The quantity.
        - parameter discountCode:          Optional discount code.
    */
    static func switchToCartAndAdd(product: String, variantId: Int, quantity: UInt, discountCode: String?) {
        switchToCartOverview()
        _ = cartViewController?.view
        cartViewController?.viewModel?.addProduct(id: product, variantId: variantId, quantity: quantity, discountCode: discountCode)
    }

    /**
        Switches back to the cart tab, and pops to root cart view controller.
    */
    static func switchToCartOverview() {
        guard let tabBarController = tabBarController, let cartNavigationController = tabBarController.viewControllers?[TabIndex.cartTab.index] as? UINavigationController else { return }

        tabBarController.selectedIndex = TabIndex.cartTab.index
        cartNavigationController.popToRootViewController(animated: true)
    }

    /**
        Switches back to the home tab, and pops to root product overview view controller.
    */
    static func switchToHome() {
        guard let tabBarController = tabBarController, let _ = productOverviewViewController?.view,
              let homeNavigationController = tabBarController.viewControllers?[TabIndex.homeTab.index] as? UINavigationController else { return }

        tabBarController.selectedIndex = TabIndex.homeTab.index
        homeNavigationController.popToRootViewController(animated: true)
    }

    /**
        Switches to the home tab, pops home navigation controller to it's root view controller, and finally loads and
        pushes the product details screen for the specified SKU.

        - parameter sku:                   SKU specifying the product variant which should be presented
                                           on the product details screen.
    */
    static func switchToProductDetails(for sku: String) {
        switchToHome()
        popHomeToProductOverview()
        productOverviewViewController?.viewModel?.presentProductDetails(for: sku)
    }

    /**
        Pops home navigation controller to it's root view controller.
    */
    static func popHomeToProductOverview() {
        guard let tabBarController = tabBarController, let homeNavigationController = tabBarController.viewControllers?[TabIndex.homeTab.index] as? UINavigationController else { return }

        homeNavigationController.popToRootViewController(animated: false)
    }

    /**
        Pops category navigation controller to it's root view controller.
    */
    static func popCategoryToRoot() {
        guard let tabBarController = tabBarController, let categoryNavigationController = tabBarController.viewControllers?[TabIndex.categoriesTab.index] as? UINavigationController else { return }

        categoryNavigationController.popToRootViewController(animated: false)
    }

    /**
        Switches back to the my account tab, and navigates to the my store view controller.
    */
    static func switchToMyStore() {
        guard let tabBarController = tabBarController,
              let accountNavigationController = tabBarController.viewControllers?[TabIndex.myAccountTab.index] as? UINavigationController,
              let accountViewController = accountViewController else { return }
        accountNavigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = TabIndex.myAccountTab.index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            accountViewController.showMyStores()
        }
    }

    /**
        Switches to the account tab, and presents reservation overview view controller.
    */
    static func showReservationDetails(id: String) {
        switchToAccount()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            accountViewController?.viewModel?.presentDetails(id: id)
        }
    }

    /**
        Switches to the account tab, and presents order details view controller.
    */
    static func showOrderDetails(orderNumber: String) {
        switchToAccount()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            accountViewController?.viewModel?.presentDetails(orderNumber: orderNumber)
        }
    }

    private static func switchToAccount() {
        guard let tabBarController = tabBarController,
              let accountNavigationController = tabBarController.viewControllers?[TabIndex.myAccountTab.index] as? UINavigationController else { return }

        accountNavigationController.popToRootViewController(animated: false)
        tabBarController.selectedIndex = TabIndex.myAccountTab.index
    }
}
