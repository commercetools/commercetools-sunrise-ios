//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import Commercetools

class ProfileViewController: UIViewController {
    

    @IBAction func logout(_ sender: UIButton) {
        Commercetools.logoutCustomer()
        AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
        AppRouting.wishListViewController?.viewModel?.refreshObserver.send(value: ())
    }
}