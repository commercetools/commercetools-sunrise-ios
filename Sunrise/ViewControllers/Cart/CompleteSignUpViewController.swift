//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class CompleteSignUpViewController: UIViewController {

    @IBOutlet weak var allowOffersSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        allowOffersSwitch.onTintColor = UIColor(patternImage: #imageLiteral(resourceName: "switch_background"))
    }
    
    @IBAction func skip(_ sender: UIButton) {
        (((presentingViewController as? UINavigationController)?.viewControllers.last as? UITabBarController)?.viewControllers?[5] as? UINavigationController)?.popViewController(animated: false)
        dismiss(animated: true)
    }

}
