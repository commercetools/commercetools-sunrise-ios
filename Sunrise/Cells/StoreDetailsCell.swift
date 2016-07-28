//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class StoreDetailsCell: UITableViewCell {

    @IBInspectable var activeColor: UIColor = UIColor.lightGrayColor()
    
    @IBOutlet weak var storeImageView: UIImageView!
    @IBOutlet weak var storeDistanceLabel: UILabel!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var availabilityIndicatorView: UIView!
    @IBOutlet weak var availabilityLabel: UILabel!    
    @IBOutlet weak var expandInfoLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var reserveButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
