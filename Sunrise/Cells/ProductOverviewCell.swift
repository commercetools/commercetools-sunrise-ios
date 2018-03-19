//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class ProductOverviewCell: UICollectionViewCell {
    
    // MARK: - Outlets

    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var wishListButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        wishListButton.setImage(#imageLiteral(resourceName: "wishlist_icon_active"), for: [.selected, .highlighted])
    }
}
