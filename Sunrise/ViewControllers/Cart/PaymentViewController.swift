//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa

class PaymentViewController: UIViewController {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var cardNumberField: UITextField!
    @IBOutlet weak var nameField: UITextField!
    @IBOutlet weak var mmField: UITextField!
    @IBOutlet weak var yyField: UITextField!
    @IBOutlet weak var cvvField: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    
    @IBOutlet var checkoutHeaderViews: [UIView]!
    
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: PaymentViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        CardIOUtilities.preloadCardIO()
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

        cardNumberField.text = viewModel.cardNumber.value
        disposables += viewModel.cardNumber <~ cardNumberField.reactive.continuousTextValues
        disposables += cardNumberField.reactive.continuousTextValues.signal
        .filter { [unowned self] in self.viewModel?.isCardNumberValid(cardNumber: $0) == false }
        .observeValues { [unowned self] in
            let correctedValue = self.viewModel?.transformInvalidCardNumber(input: $0)
            self.cardNumberField.text = correctedValue
            self.viewModel?.cardNumber.value = correctedValue
        }

        nameField.text = viewModel.name.value
        disposables += viewModel.name <~ nameField.reactive.continuousTextValues

        mmField.text = viewModel.expiryMonth.value
        disposables += viewModel.expiryMonth <~ mmField.reactive.continuousTextValues
        disposables += mmField.reactive.continuousTextValues.signal
        .filter { [unowned self] in self.viewModel?.isExpiryMonthValid(expiryMonth: $0) == false }
        .observeValues { [unowned self] in
            let correctedValue = self.viewModel?.transformInvalidExpiryMonth(input: $0)
            self.mmField.text = correctedValue
            self.viewModel?.expiryMonth.value = correctedValue
        }

        yyField.text = viewModel.expiryYear.value
        disposables += viewModel.expiryYear <~ yyField.reactive.continuousTextValues
        disposables += yyField.reactive.continuousTextValues.signal
        .filter { [unowned self] in self.viewModel?.isExpiryYearValid(expiryYear: $0) == false }
        .observeValues { [unowned self] in
            let correctedValue = self.viewModel?.transformInvalidExpiryYear(input: $0)
            self.yyField.text = correctedValue
            self.viewModel?.expiryYear.value = correctedValue
        }

        cvvField.text = viewModel.ccv.value
        disposables += viewModel.ccv <~ cvvField.reactive.continuousTextValues
        disposables += cvvField.reactive.continuousTextValues.signal
        .filter { [unowned self] in self.viewModel?.isCcvValid(ccv: $0) == false }
        .observeValues { [unowned self] in
            let correctedValue = self.viewModel?.transformInvalidCcv(input: $0)
            self.cvvField.text = correctedValue
            self.viewModel?.ccv.value = correctedValue
        }

        disposables += saveButton.reactive.isEnabled <~ viewModel.isPaymentValid

        disposables += viewModel.saveAction.completed
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.navigationController?.popViewController(animated: true)
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
    
    
    @IBAction func scanCard(_ sender: UIButton) {
        guard let scanViewController = CardIOPaymentViewController(paymentDelegate: self) else { return }
        scanViewController.hideCardIOLogo = true
        present(scanViewController, animated: true)
    }
    
    @IBAction func backToCheckout(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}

extension PaymentViewController: CardIOPaymentViewControllerDelegate {
    func userDidCancel(_ paymentViewController: CardIOPaymentViewController!) {
        paymentViewController.dismiss(animated: true)
    }
    
    func userDidProvide(_ cardInfo: CardIOCreditCardInfo!, in paymentViewController: CardIOPaymentViewController!) {
        cardNumberField.text = cardInfo.cardNumber
        nameField.text = cardInfo.cardholderName
        mmField.text = String(format: "%02d", cardInfo.expiryMonth)
        let expiryYear = "\(cardInfo.expiryYear)"
        yyField.text = expiryYear.count > 2 ? String(expiryYear.suffix(from: expiryYear.index(expiryYear.endIndex, offsetBy: -2))) : expiryYear
        cvvField.text = cardInfo.cvv
        paymentViewController.dismiss(animated: true)
    }
}
