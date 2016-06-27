//
//  OrdersHeaderView.swift
//  Sunrise
//
//  Created by Nikola Mladenovic on 6/26/16.
//  Copyright © 2016 Commercetools. All rights reserved.
//

import UIKit

class OrdersHeaderView: UIView {
    
    @IBInspectable var activeColor: UIColor = UIColor.lightGrayColor()
    @IBInspectable var inactiveColor: UIColor = UIColor.whiteColor()
    
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var columnDescriptionView: UIView!
    @IBOutlet weak var expansionIcon: UIImageView!
    
}
