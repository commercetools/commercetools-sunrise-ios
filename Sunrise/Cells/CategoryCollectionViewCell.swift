//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class CategoryCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var categoryImageView: UIImageView!
    @IBOutlet weak var categoryNameLabel: UILabel!
    
    override func awakeFromNib() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        gradientLayer.opacity = 0.35
        let screenWidth = UIScreen.main.bounds.width
        let cellWidth = (screenWidth - 30) / 2
        gradientLayer.frame = CGRect(x: 0, y: cellWidth * 0.523, width: cellWidth, height: cellWidth * 0.360)
        categoryImageView.layer.insertSublayer(gradientLayer, at: 0)
    }
}