//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import IQDropDownTextField

class SelectableAttributeCell: UITableViewCell {

    @IBInspectable var attributesBorderColor: UIColor = UIColor.gray

    @IBOutlet weak var attributeLabel: UILabel!
    @IBOutlet weak var attributeField: IQDropDownTextField!

    override func awakeFromNib() {
        super.awakeFromNib()

        attributeField.layer.borderColor = attributesBorderColor.cgColor
    }

}
