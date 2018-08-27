//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Foundation

class SunriseTabBarController: UITabBarController {
    
    enum RightNavItemMode {
        case cart
        case doneButton
    }

    static var currentlyActive: SunriseTabBarController?
    
    @IBOutlet var tabView: UIView!
    @IBOutlet var navigationView: UIView!
    @IBOutlet weak var navigationBarLogoImageView: UIImageView!

    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var barcodeButton: UIButton!    
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var wishListButton: UIButton!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var cartButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var wishListBadgeImageView: UIImageView!
    @IBOutlet weak var wishListBadgeLabel: UILabel!
    @IBOutlet weak var cartBadgeImageView: UIImageView!
    @IBOutlet weak var cartBadgeLabel: UILabel!
    
    private lazy var tabButtons: [UIButton] = {
        return [homeButton, barcodeButton, searchButton, wishListButton, profileButton]
    }()
    
    var wishListBadge: Int = 1 {
        didSet {
            wishListBadgeLabel.text = String(wishListBadge)
            wishListBadgeLabel.isHidden = wishListBadge < 1
            wishListBadgeImageView.isHidden = wishListBadge < 1
        }
    }

    var cartBadge: Int = 1 {
        didSet {
            cartBadgeLabel.text = String(cartBadge)
            cartBadgeLabel.isHidden = cartBadge < 1
            cartBadgeImageView.isHidden = cartBadge < 1
        }
    }
    
    var navigationBarLightMode: Bool {
        set {
            navigationView.backgroundColor = newValue ? UIColor.clear : .white
            navigationView.layer.shadowColor = newValue ? UIColor.clear.cgColor : UIColor.black.cgColor
            navigationBarLogoImageView.alpha = newValue ? 0 : 1
        }
        get {
            return navigationBarLogoImageView.isHidden
        }
    }

    var rightNavItemModel: RightNavItemMode {
        set {
            cartButton.isHidden = newValue == .doneButton
            doneButton.isHidden = newValue == .cart
            if newValue == .doneButton {
                cartBadgeLabel.isHidden = true
                cartBadgeImageView.isHidden = true
            } else {
                let currentCartBadge = cartBadge
                cartBadge = currentCartBadge
            }
        }
        get {
            return cartButton.isHidden ? .doneButton : .cart
        }
    }

    override var selectedIndex: Int {
        didSet {
            setupTabButtonAppearance()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        SunriseTabBarController.currentlyActive = self
        // Hide navigation bar from more navigation controller
        moreNavigationController.navigationBar.isHidden = true

        homeButton.setImage(#imageLiteral(resourceName: "home_tab_sel"), for: [.selected, .highlighted])
        barcodeButton.setImage(#imageLiteral(resourceName: "barcode_tab_sel"), for: [.selected, .highlighted])
        searchButton.setImage(#imageLiteral(resourceName: "search_tab_sel"), for: [.selected, .highlighted])
        wishListButton.setImage(#imageLiteral(resourceName: "wishlist_tab_sel"), for: [.selected, .highlighted])
        profileButton.setImage(#imageLiteral(resourceName: "profile_tab_sel"), for: [.selected, .highlighted])
        cartButton.setImage(#imageLiteral(resourceName: "nav_bar_bag_active"), for: [.selected, .highlighted])
        
        homeButton.isSelected = true
        
        tabView.layer.shadowColor = UIColor.black.cgColor
        var pathRect = tabView.bounds
        pathRect.size.height = 10
        tabView.layer.shadowPath = UIBezierPath(rect: pathRect).cgPath
        tabView.layer.shadowRadius = 4
        tabView.layer.shadowOffset = CGSize(width: 0, height: 4)
        tabView.layer.shadowOpacity = 0.5
        
        navigationView.layer.shadowColor = UIColor.black.cgColor
        pathRect = navigationView.bounds
        pathRect.size.height = 10
        pathRect.origin.y += navigationView.bounds.size.height
        pathRect.origin.y -= 20
        navigationView.layer.shadowPath = UIBezierPath(rect: pathRect).cgPath
        navigationView.layer.shadowRadius = 6
        navigationView.layer.shadowOffset = CGSize(width: 0, height: 9)
        navigationView.layer.shadowOpacity = 0.2
        
        let guide = view.safeAreaLayoutGuide
        
        tabView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabView)
        guide.leftAnchor.constraint(equalTo: tabView.leftAnchor).isActive = true
        guide.rightAnchor.constraint(equalTo: tabView.rightAnchor).isActive = true
        guide.bottomAnchor.constraint(equalTo: tabView.bottomAnchor).isActive = true
        tabView.heightAnchor.constraint(equalToConstant: 53).isActive = true
        
        navigationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationView)
        guide.leftAnchor.constraint(equalTo: navigationView.leftAnchor).isActive = true
        guide.rightAnchor.constraint(equalTo: navigationView.rightAnchor).isActive = true
        guide.topAnchor.constraint(equalTo: navigationView.topAnchor).isActive = true
        navigationView.heightAnchor.constraint(equalToConstant: 53).isActive = true

        tabBar.isHidden = true

        // Load views, so view models can start fetching data
        _ = AppRouting.mainViewController?.view
        _ = AppRouting.cartViewController?.view
        _ = AppRouting.wishListViewController?.view
        _ = AppRouting.profileViewController?.view
    }

    @IBAction func touchUpInside(_ sender: UIButton) {
        guard let index = tabButtons.index(of: sender) else { return }
        if index == AppRouting.TabIndex.mainTab.index && AppRouting.isProductOverviewOnMainTabPresented {
            NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.resetSearch, object: nil, userInfo: nil)
        }
        selectedIndex = index
    }

    @IBAction func backButtonTouchUpInside(_ sender: UIButton) {
        NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.backButtonTapped, object: nil, userInfo: nil)
    }

    @IBAction func doneButtonTouchUpInside(_ sender: UIButton) {
        NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.doneButtonTapped, object: nil, userInfo: nil)
    }

    @IBAction func cartButtonTouchUpInside(_ sender: UIButton) {
        guard !sender.isSelected else { return }
        selectedIndex = tabButtons.count
        sender.isSelected = true
    }

    private func setupTabButtonAppearance() {
        for (index, button) in tabButtons.enumerated() {
            button.isSelected = selectedIndex == index
        }
        cartButton.isSelected = false
        wishListBadgeImageView.image = selectedIndex == tabButtons.index(of: wishListButton) ? #imageLiteral(resourceName: "tab_wishlist_badge") : #imageLiteral(resourceName: "tab_wishlist_off_badge")
    }
}

extension SunriseTabBarController: UITabBarControllerDelegate {

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        return true
    }
}

public extension Foundation.Notification.Name {
    /// Used as a namespace for all notifications related to watch token synchronization.
    public struct Navigation {
        public static let backButtonTapped = Foundation.Notification.Name(rawValue: "com.commercetools.notification.navigation.backButtonTapped")
        public static let doneButtonTapped = Foundation.Notification.Name(rawValue: "com.commercetools.notification.navigation.doneButtonTapped")
        public static let resetSearch = Foundation.Notification.Name(rawValue: "com.commercetools.notification.navigation.resetSearch")
    }
}
