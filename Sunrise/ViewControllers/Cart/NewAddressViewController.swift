//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result
import SVProgressHUD
import IQDropDownTextField

class NewAddressViewController: UIViewController {
    
    @IBInspectable var borderColor: UIColor = UIColor.lightGray
    
    @IBOutlet weak var shippingFormView: UIView!
    @IBOutlet weak var titleField: IQDropDownTextField!
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var address1Field: UITextField!
    @IBOutlet weak var address2Field: UITextField!
    @IBOutlet weak var cityField: UITextField!
    @IBOutlet weak var postCodeField: UITextField!
    @IBOutlet weak var countryField: IQDropDownTextField!    
    @IBOutlet weak var regionField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var emailField: UITextField!
    
    private var viewModel: NewAddressViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        emailField.keyboardType = .emailAddress
        titleField.dropDownMode = .textPicker
        countryField.dropDownMode = .textPicker

        shippingFormView.layer.borderColor = borderColor.cgColor

        [titleField, firstNameField, lastNameField, address1Field, address2Field, cityField, postCodeField, countryField,
         regionField, phoneField, emailField].forEach {
            $0?.layer.borderColor = borderColor.cgColor
            $0?.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 7, height: ($0?.frame.height)!))
            $0?.leftViewMode = .always
        }
        
        viewModel = NewAddressViewModel()
    }
    

    // MARK: - Bindings
    
    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        viewModel.title <~ titleField.reactive.textValues.map { $0 ?? "" }
        viewModel.firstName <~ firstNameField.reactive.textValues.map { $0 ?? "" }
        viewModel.lastName <~ lastNameField.reactive.textValues.map { $0 ?? "" }
        viewModel.address1 <~ address1Field.reactive.textValues.map { $0 ?? "" }
        viewModel.address2 <~ address2Field.reactive.textValues.map { $0 ?? "" }
        viewModel.postCode <~ postCodeField.reactive.textValues.map { $0 ?? "" }
        viewModel.city <~ cityField.reactive.textValues.map { $0 ?? "" }
        viewModel.region <~ regionField.reactive.textValues.map { $0 ?? "" }
        viewModel.country <~ countryField.reactive.textValues.map { $0 ?? "" }
    }
    
}
