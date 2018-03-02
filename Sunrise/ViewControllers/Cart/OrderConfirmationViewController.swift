//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit

class OrderConfirmationViewController: UIViewController {

    @IBAction func continueShopping(_ sender: UIButton) {
        AppRouting.showMainTab()
        SunriseTabBarController.currentlyActive?.tabView.alpha = 1
        SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
        AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
        dismiss(animated: false)
    }
}