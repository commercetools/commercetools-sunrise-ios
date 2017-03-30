//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result
import SVProgressHUD
import IQDropDownTextField

class ConfirmationViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGray

    @IBOutlet weak var formView: UIView!
    
    @IBOutlet weak var shippingFirstNameLabel: UILabel!
    @IBOutlet weak var shippingLastNameLabel: UILabel!
    @IBOutlet weak var shippingStreetNameLabel: UILabel!
    @IBOutlet weak var shippingCityLabel: UILabel!
    @IBOutlet weak var shippingPostalCodeLabel: UILabel!
    @IBOutlet weak var shippingRegionLabel: UILabel!
    @IBOutlet weak var shippingCountryLabel: UILabel!

    @IBOutlet weak var billingFirstNameLabel: UILabel!
    @IBOutlet weak var billingLastNameLabel: UILabel!
    @IBOutlet weak var billingStreetNameLabel: UILabel!
    @IBOutlet weak var billingCityLabel: UILabel!
    @IBOutlet weak var billingPostalCodeLabel: UILabel!
    @IBOutlet weak var billingRegionLabel: UILabel!
    @IBOutlet weak var billingCountryLabel: UILabel!
    
    @IBOutlet weak var shippingMethodNameLabel: UILabel!
    @IBOutlet weak var shippingMethodDescriptionLabel: UILabel!
    @IBOutlet weak var paymentLabel: UILabel!
    
    @IBOutlet weak var completeOrderButton: UIButton!

    private var viewModel: ConfirmationViewModel? {
        didSet {
            bindViewModel()
        }
    }

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        formView.layer.borderColor = borderColor.cgColor
        viewModel = ConfirmationViewModel()
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        shippingFirstNameLabel.reactive.text <~ viewModel.shippingFirstName
        shippingLastNameLabel.reactive.text <~ viewModel.shippingLastName
        shippingStreetNameLabel.reactive.text <~ viewModel.shippingStreetName
        shippingCityLabel.reactive.text <~ viewModel.shippingCity
        shippingPostalCodeLabel.reactive.text <~ viewModel.shippingPostalCode
        shippingRegionLabel.reactive.text <~ viewModel.shippingRegion
        shippingCountryLabel.reactive.text <~ viewModel.shippingCountry
        billingFirstNameLabel.reactive.text <~ viewModel.billingFirstName
        billingLastNameLabel.reactive.text <~ viewModel.billingLastName
        billingStreetNameLabel.reactive.text <~ viewModel.billingStreetName
        billingCityLabel.reactive.text <~ viewModel.billingCity
        billingPostalCodeLabel.reactive.text <~ viewModel.billingPostalCode
        billingRegionLabel.reactive.text <~ viewModel.billingRegion
        billingCountryLabel.reactive.text <~ viewModel.billingCountry
        shippingMethodNameLabel.reactive.text <~ viewModel.shippingMethodName
        shippingMethodDescriptionLabel.reactive.text <~ viewModel.shippingMethodDescription
        paymentLabel.reactive.text <~ viewModel.payment

        completeOrderButton.reactive.pressed = CocoaAction(viewModel.continueCheckoutAction)

        disposables += viewModel.orderCreatedSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] alertMessage in
            let alertController = UIAlertController(
                    title: self?.viewModel?.orderCreatedTitle,
                    message: self?.viewModel?.orderCreatedMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                AppRouting.switchToHome()
                _ = self?.navigationController?.popToRootViewController(animated: false)
            }))
            self?.present(alertController, animated: true, completion: nil)
        })

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}
