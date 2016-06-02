//
//  CartItemCell.swift
//  Sunrise
//
//  Created by Nikola Mladenovic on 5/31/16.
//  Copyright © 2016 Commercetools. All rights reserved.
//

import UIKit

class CartItemCell: UITableViewCell {

    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var totalPriceLabel: UILabel!
    @IBOutlet weak var skuLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    override func prepareForReuse() {
        super.prepareForReuse()

        productImageView.image = nil
    }

}
