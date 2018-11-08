//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class CartLineItemCell: UITableViewCell {

    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var colorView: UIView!

    @IBOutlet weak var wishListButton: UIButton?
    @IBOutlet weak var removeLineItemButton: UIButton?

    @IBOutlet weak var oldAndActivePriceSpacingConstraint: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        wishListButton?.setImage(#imageLiteral(resourceName: "wishlist_icon_active"), for: [.selected, .highlighted])
        colorView.layer.borderColor = UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0).cgColor
    }
}
