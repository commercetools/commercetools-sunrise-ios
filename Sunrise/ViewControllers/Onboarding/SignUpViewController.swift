//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class SignUpViewController: UIViewController {
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let placeholderAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red: 0.34, green: 0.37, blue: 0.40, alpha: 1.0)]
        emailField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Username", comment: "Username"), attributes: placeholderAttributes)
        passwordField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("Password", comment: "Password"), attributes: placeholderAttributes)
    }
}
