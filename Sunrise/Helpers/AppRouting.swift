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

    struct ShowReservationDetailsRequest {
        let reservationId: String
    }

    static let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)

    static let homeStoryboard = UIStoryboard(name: "Home", bundle: nil)

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

    static func showProfileTab() {
        profileViewController?.navigationController?.popToRootViewController(animated: false)
        SunriseTabBarController.currentlyActive?.selectedIndex = TabIndex.profileTab.index
    }

    static func showProductDetails(for sku: String) {
        showMainTab()
        mainViewController?.viewModel?.productsViewModel.presentProductDetails(for: sku)
    }

    static func showCategory(id: String) {
        resetMainViewControllerState {
            mainViewController?.viewModel?.setActiveCategory(id: id)
        }
        showMainTab()
    }

    static func showProductOverview(with additionalFilters: [String]) {
        showMainTab()
        mainViewController?.viewModel?.showProductsOverview(with: additionalFilters)
    }

    static func showMyOrders() {
        showProfileTab()
        profileViewController?.performSegue(withIdentifier: "showMyOrders", sender: profileViewController)
    }

    static func showReservationDetails(for reservationId: String) {
        showProfileTab()
        profileViewController?.performSegue(withIdentifier: "showMyReservations", sender: ShowReservationDetailsRequest(reservationId: reservationId))
    }

    static func search(query: String, filters: [URLQueryItem]) {
        resetMainViewControllerState {
            showMainTab()
            guard let mainViewController = mainViewController, let filtersViewModel = mainViewController.viewModel?.productsViewModel.filtersViewModel else { return }
            filtersViewModel.activeColors.value = Set(filters[FiltersViewModel.kColorsAttributeName])
            filtersViewModel.activeBrands.value = Set(filters[FiltersViewModel.kBrandAttributeName])
            filtersViewModel.activeSizes.value = Set(filters["size"]) // Sunrise web is using different attribute for size filter, but values mostly match
            mainViewController.searchFilterButton.isSelected = filtersViewModel.hasFiltersApplied
            mainViewController.searchField.becomeFirstResponder()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                mainViewController.searchField.text = query
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    mainViewController.searchField.resignFirstResponder()
                }
            }
        }
    }

    static func switchToCartTab() {
        SunriseTabBarController.currentlyActive?.selectedIndex = TabIndex.cartTab.index
        SunriseTabBarController.currentlyActive?.cartButton.isSelected = true
    }

    private static func resetMainViewControllerState(completion: @escaping () -> Swift.Void) {
        NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.resetSearch, object: nil, userInfo: nil)
        // Continue after reset animations have completed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            completion()
        }
    }
}
