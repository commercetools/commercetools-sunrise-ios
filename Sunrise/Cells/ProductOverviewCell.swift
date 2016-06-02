//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class ProductOverviewCell: UICollectionViewCell {
    
    @IBInspectable var borderColor: UIColor = UIColor.lightGrayColor()
    
    // MARK: - Outlets

    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.borderColor = borderColor.CGColor
    }
    
}
