//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class PaymentCell: UICollectionViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var last4DigitsLabel: UILabel!
    @IBOutlet weak var cellSelectedImageView: UIImageView?
    @IBOutlet weak var defaultPaymentLabel: UILabel?
    @IBOutlet weak var makeDefaultPaymentLabel: UILabel?
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var makeDefaultButton: UIButton?
    @IBOutlet weak var removeButton: UIButton?
}
