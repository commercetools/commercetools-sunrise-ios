//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit

class WishListCell: UITableViewCell {
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var addToBagButton: UIButton!
    @IBOutlet weak var wishListButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        wishListButton.setImage(#imageLiteral(resourceName: "wishlist_icon_active"), for: [.selected, .highlighted])
    }
}

