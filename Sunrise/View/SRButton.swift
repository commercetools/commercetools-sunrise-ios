//
// Copyright (c) 2017 Commercetools. All rights reserved.
//
import UIKit

@IBDesignable class SRButton: UIButton {

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAppearance()
    }

    // MARK: - Appearance

    private func setupAppearance() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.cornerRadius = 3
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.cornerRadius = 3
        gradientLayer.colors = [UIColor(red:1.00, green:0.53, blue:0.33, alpha:1.0).cgColor, UIColor(red:1.00, green:0.28, blue:0.39, alpha:1.0).cgColor]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        layer.insertSublayer(gradientLayer, at: 0)
    }
}
