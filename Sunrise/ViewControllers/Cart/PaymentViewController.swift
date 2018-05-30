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

        // Do any additional setup after loading the view.
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        saveButton.reactive.pressed = CocoaAction(viewModel.saveAction)

        disposables += titleLabel.reactive.text <~ viewModel.title

        cardNumberField.text = viewModel.cardNumber.value
        disposables += viewModel.cardNumber <~ cardNumberField.reactive.continuousTextValues

        nameField.text = viewModel.name.value
        disposables += viewModel.name <~ nameField.reactive.continuousTextValues

        mmField.text = viewModel.expiryMonth.value
        disposables += viewModel.expiryMonth <~ mmField.reactive.continuousTextValues

        yyField.text = viewModel.expiryYear.value
        disposables += viewModel.expiryYear <~ yyField.reactive.continuousTextValues

        cvvField.text = viewModel.ccv.value
        disposables += viewModel.ccv <~ cvvField.reactive.continuousTextValues

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

    @IBAction func backToCheckout(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}
