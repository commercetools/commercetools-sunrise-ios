//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit

class OrdersHeaderView: UIView {
    
    @IBInspectable var activeColor: UIColor = UIColor.lightGray
    @IBInspectable var inactiveColor: UIColor = UIColor.white
    
    @IBOutlet weak var footerSeparatorLineHeight: NSLayoutConstraint!
    @IBOutlet weak var columnTitlesHeight: NSLayoutConstraint!
    
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var expansionIcon: UIImageView!

    var columnDescriptionViewHidden: Bool {
        get {
            return footerSeparatorLineHeight.constant == 0
        }
        set(hidden) {
            footerSeparatorLineHeight.constant = hidden ? 0 : 1
            columnTitlesHeight.constant = hidden ? 0 : 25
        }
    }

}
