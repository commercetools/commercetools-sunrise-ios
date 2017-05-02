//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class SunriseTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self
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
