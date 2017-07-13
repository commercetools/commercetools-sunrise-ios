//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class CartSummaryCell: UITableViewCell {

    @IBInspectable var borderColor: UIColor = UIColor.lightGray

    // MARK: - Outlets

    @IBOutlet weak var subtotalLabel: UILabel!
    @IBOutlet weak var orderDiscountLabel: UILabel!
    @IBOutlet weak var taxLabel: UILabel!
    @IBOutlet weak var taxDescriptionLabel: UILabel!
    @IBOutlet weak var orderTotalLabel: UILabel!
    @IBOutlet weak var checkoutButton: UIButton!
    @IBOutlet weak var discountInfoButton: UIButton!
    @IBOutlet weak var addDiscountButton: UIButton?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        addDiscountButton?.layer.borderColor = borderColor.cgColor
    }
    
}
