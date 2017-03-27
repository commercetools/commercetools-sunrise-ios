//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class AddressCell: UITableViewCell {
    
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var firstNameLabel: UILabel?
    @IBOutlet weak var lastNameLabel: UILabel?
    @IBOutlet weak var streetNameLabel: UILabel?
    @IBOutlet weak var cityLabel: UILabel?
    @IBOutlet weak var postalCodeLabel: UILabel?
    @IBOutlet weak var regionLabel: UILabel?
    @IBOutlet weak var countryLabel: UILabel?
    @IBOutlet weak var borderView: UIView!

    var hasBorder: Bool {
        set {
            borderView.layer.borderWidth = newValue ? 1 : 0
            borderView.layer.borderColor = UIColor(red: 0.84, green: 0.84, blue: 0.84, alpha: 1.0).cgColor
        }
        get {
            return borderView.layer.borderWidth > 0
        }
    }

    var hasBackgroundColor: Bool {
        set {
            borderView.backgroundColor = newValue ? UIColor(red: 0.96, green: 0.96, blue: 0.96, alpha: 1.0) : UIColor.clear
        }
        get {
            return borderView.backgroundColor != UIColor.clear
        }
    }
}
