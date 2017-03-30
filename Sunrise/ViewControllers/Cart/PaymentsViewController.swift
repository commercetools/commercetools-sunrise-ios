//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class PaymentsViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGray

    @IBOutlet weak var formView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        formView.layer.borderColor = borderColor.cgColor
    }
}
