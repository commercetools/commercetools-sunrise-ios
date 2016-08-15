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

    func tabBarController(tabBarController: UITabBarController, shouldSelectViewController viewController: UIViewController) -> Bool {
        // Until placing custom search view controller, invoke search bar on home tab.
        if viewController == tabBarController.viewControllers?[1] {
            AppRouting.switchToSearch()
            return false

        } else {
            return true
        }
    }

}