//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class SunriseTabBarController: UITabBarController {
    
    @IBOutlet var tabView: UIView!
    @IBOutlet var navigationView: UIView!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var barcodeButton: UIButton!    
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var wishlistButton: UIButton!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var wishlistBadgeImageView: UIImageView!
    @IBOutlet weak var wishlistBadgeLabel: UILabel!
    
    private lazy var tabButtons: [UIButton] = {
        return [homeButton, barcodeButton, searchButton, wishlistButton, profileButton]
    }()
    
    var wishlistBadge: Int = 1 {
        didSet {
            wishlistBadgeLabel.text = String(wishlistBadge)
            wishlistBadgeLabel.isHidden = wishlistBadge < 1
            wishlistBadgeImageView.isHidden = wishlistBadge < 1
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

        homeButton.setImage(#imageLiteral(resourceName: "home_tab_sel"), for: [.selected, .highlighted])
        barcodeButton.setImage(#imageLiteral(resourceName: "barcode_tab_sel"), for: [.selected, .highlighted])
        searchButton.setImage(#imageLiteral(resourceName: "search_tab_sel"), for: [.selected, .highlighted])
        wishlistButton.setImage(#imageLiteral(resourceName: "wishlist_tab_sel"), for: [.selected, .highlighted])
        profileButton.setImage(#imageLiteral(resourceName: "profile_tab_sel"), for: [.selected, .highlighted])
        
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
        if #available(iOS 11, *) {
            pathRect.origin.y -= 20
        }
        navigationView.layer.shadowPath = UIBezierPath(rect: pathRect).cgPath
        navigationView.layer.shadowRadius = 6
        navigationView.layer.shadowOffset = CGSize(width: 0, height: 9)
        navigationView.layer.shadowOpacity = 0.2
        
        if #available(iOS 11, *) {
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
            
        } else {
            tabView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(tabView)
            view.leftAnchor.constraint(equalTo: tabView.leftAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: tabView.rightAnchor).isActive = true
            view.bottomAnchor.constraint(equalTo: tabView.bottomAnchor).isActive = true
            tabView.heightAnchor.constraint(equalToConstant: 53).isActive = true
            
            navigationView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(navigationView)
            view.leftAnchor.constraint(equalTo: navigationView.leftAnchor).isActive = true
            view.rightAnchor.constraint(equalTo: navigationView.rightAnchor).isActive = true
            view.topAnchor.constraint(equalTo: navigationView.topAnchor).isActive = true
            navigationView.heightAnchor.constraint(equalToConstant: 73).isActive = true
        }

        tabBar.isHidden = true
    }

    @IBAction func touchUpInside(_ sender: UIButton) {
        guard let index = tabButtons.index(of: sender) else { return }
        selectedIndex = index
    }

    private func setupTabButtonAppearance() {
        for (index, button) in tabButtons.enumerated() {
            button.isSelected = selectedIndex == index
        }
        wishlistBadgeImageView.image = selectedIndex == tabButtons.index(of: wishlistButton) ? #imageLiteral(resourceName: "tab_wishlist_badge") : #imageLiteral(resourceName: "tab_wishlist_off_badge")
    }
}

extension SunriseTabBarController: UITabBarControllerDelegate {

    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // Until placing custom search view controller, invoke search bar on home tab.
        if viewController == tabBarController.viewControllers?[AppRouting.TabIndex.searchTab.index] {
            AppRouting.switchToSearch(becomeFirstResponder: true)
            return false

        } else {
            return true
        }
    }

}
