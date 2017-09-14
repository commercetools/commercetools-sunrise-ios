//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class SunriseTabBarController: UITabBarController {

    @IBOutlet var tabView: UIView!
    @IBOutlet weak var homeButton: UIButton!
    @IBOutlet weak var barcodeButton: UIButton!    
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var wishlistButton: UIButton!
    @IBOutlet weak var profileButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
        
        [homeButton, barcodeButton, searchButton, wishlistButton, profileButton].forEach { $0?.setBackgroundImage(#imageLiteral(resourceName: "active_tab_background"), for: [.selected, .highlighted]) }
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
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        view.addSubview(tabView)
        var tabBarFrame = tabBar.frame
        tabBarFrame.size.height = 53
        tabView.frame = tabBarFrame
        
        tabBar.isHidden = true
        homeButton.isSelected = true
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
