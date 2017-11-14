//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class OrderConfirmationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func continueShopping(_ sender: UIButton) {
        (((presentingViewController as? UINavigationController)?.viewControllers.last as? UITabBarController)?.viewControllers?[5] as? UINavigationController)?.popViewController(animated: false)
        dismiss(animated: true)
    }
}
