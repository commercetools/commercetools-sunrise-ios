//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import IQDropDownTextField
import SVProgressHUD
import ContactsUI

class AddressViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var phoneField: UITextField!
    @IBOutlet weak var addressLine1Field: UITextField!
    @IBOutlet weak var addressLine2Field: UITextField!
    @IBOutlet weak var cityField: UITextField!
    @IBOutlet weak var postalCodeField: UITextField!
    @IBOutlet weak var stateField: IQDropDownTextField!
    @IBOutlet weak var countryField: IQDropDownTextField!
    
    @IBOutlet weak var saveButton: UIButton!
    
    @IBOutlet var checkoutHeaderViews: [UIView]!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: AddressViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let placeholderAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red: 0.34, green: 0.37, blue: 0.40, alpha: 1.0)]
        [firstNameField, lastNameField, phoneField, addressLine1Field, addressLine2Field, cityField, postalCodeField, stateField, countryField].forEach {
            let text = $0?.placeholder
            $0?.attributedPlaceholder = NSAttributedString(string: text ?? "", attributes: placeholderAttributes)
        }

        stateField.itemList = ["Alabama", "Alaska", "Arizona", "Arkansas", "California", "Colorado", "Connecticut", "Delaware", "Florida", "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", "Iowa", "Kansas", "Kentucky", "Louisiana", "Maine", "Maryland", "Massachusetts", "Michigan", "Minnesota", "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", "New Hampshire", "New Jersey", "New Mexico", "New York", "North Carolina", "North Dakota", "Ohio", "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", "South Carolina", "South Dakota", "Tennessee", "Texas", "Utah", "Vermont", "Virginia", "Washington", "West Virginia", "Wisconsin", "Wyoming"]
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        saveButton.reactive.pressed = CocoaAction(viewModel.saveAction)

        disposables += titleLabel.reactive.text <~ viewModel.title

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss() }

        firstNameField.text = viewModel.firstName.value
        disposables += viewModel.firstName <~ firstNameField.reactive.continuousTextValues

        lastNameField.text = viewModel.lastName.value
        disposables += viewModel.lastName <~ lastNameField.reactive.continuousTextValues

        phoneField.text = viewModel.phone.value
        disposables += viewModel.phone <~ phoneField.reactive.continuousTextValues

        addressLine1Field.text = viewModel.address1.value
        disposables += viewModel.address1 <~ addressLine1Field.reactive.continuousTextValues

        addressLine2Field.text = viewModel.address2.value
        disposables += viewModel.address2 <~ addressLine2Field.reactive.continuousTextValues

        cityField.text = viewModel.city.value
        disposables += viewModel.city <~ cityField.reactive.continuousTextValues

        postalCodeField.text = viewModel.postCode.value
        disposables += viewModel.postCode <~ postalCodeField.reactive.continuousTextValues

        stateField.selectedItem = viewModel.state.value
        disposables += viewModel.state <~ stateField.reactive.continuousTextValues

        countryField.selectedItem = viewModel.country.value
        disposables += viewModel.country <~ countryField.reactive.continuousTextValues

        disposables += saveButton.reactive.isEnabled <~ viewModel.isAddressValid

        disposables += viewModel.isStateEnabled.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in
            self?.stateField.isEnabled = $0
            self?.stateField.alpha = $0 ? 1 : 0.7
            if !$0 {
                self?.stateField.selectedItem = nil
                self?.viewModel?.state.value = nil
            }
        }

        disposables += viewModel.countries.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] countryCodes in
            self?.countryField.itemList = countryCodes.map { return $0.0 }
            self?.countryField.selectedItem = self?.viewModel?.country.value
        }

        disposables += viewModel.saveAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
                case .value:
                    self?.navigationController?.popViewController(animated: true)
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: self?.viewModel?.oopsTitle,
                            message: self?.viewModel?.alertMessage(for: [error]),
                            preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                default:
                    return
            }
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.navigationController?.popViewController(animated: true)
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    @IBAction func addFromContacts(_ sender: UIButton) {
        let pickerViewController = CNContactPickerViewController()
        pickerViewController.delegate = self
        present(pickerViewController, animated: true)
    }
    
    @IBAction func backToCheckout(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}

extension AddressViewController: CNContactPickerDelegate {
    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        firstNameField.text = contact.givenName
        viewModel?.firstName.value = contact.givenName
        lastNameField.text = contact.familyName
        viewModel?.lastName.value = contact.familyName
        phoneField.text = contact.phoneNumbers.first?.value.stringValue
        viewModel?.phone.value = phoneField.text
        let address = contact.postalAddresses.first?.value
        addressLine1Field.text = address?.street
        viewModel?.address1.value = addressLine1Field.text
        addressLine2Field.text = address?.subLocality
        viewModel?.address2.value = addressLine2Field.text
        cityField.text = address?.city
        viewModel?.city.value = cityField.text
        postalCodeField.text = address?.postalCode
        viewModel?.postCode.value = postalCodeField.text
        countryField.selectedItem = address?.country
        viewModel?.country.value = countryField.selectedItem
        stateField.selectedItem = address?.state
        viewModel?.state.value = stateField.selectedItem
    }
}
