//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class OnboardingViewController: UIViewController {
    
    @IBOutlet weak var gradientView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor(red:0.20, green:0.58, blue:1.00, alpha:1.0).cgColor, UIColor(red:0.22, green:0.96, blue:1.00, alpha:1.0).cgColor]
        gradientLayer.locations = [0.054, 0.541]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

