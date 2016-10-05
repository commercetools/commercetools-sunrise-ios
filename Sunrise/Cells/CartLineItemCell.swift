//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import IQDropDownTextField

class CartLineItemCell: UITableViewCell {

    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel?
    @IBOutlet weak var quantityField: IQDropDownTextField?
    @IBOutlet weak var totalPriceLabel: UILabel!
    @IBOutlet weak var skuLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    @IBAction func editQuantity(_ sender: AnyObject) {
        quantityField?.becomeFirstResponder()
    }    

}
