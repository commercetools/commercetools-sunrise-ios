//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class SignInViewController: UIViewController {

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!

    @IBOutlet weak var logInButton: UIButton!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: SignInViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let placeholderAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red: 0.34, green: 0.37, blue: 0.40, alpha: 1.0)]
        emailField.attributedPlaceholder = NSAttributedString(string: "Username", attributes: placeholderAttributes)
        passwordField.attributedPlaceholder = NSAttributedString(string: "Password", attributes: placeholderAttributes)

        viewModel = SignInViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !(parent is ProfileViewController) else { return }
        UIView.animate(withDuration: 0.15) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
            SunriseTabBarController.currentlyActive?.backButton.alpha = 1
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        guard !(parent is ProfileViewController) else { return }
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.username <~ emailField.reactive.continuousTextValues.map { $0 ?? "" }
        disposables += viewModel.password <~ passwordField.reactive.continuousTextValues.map { $0 ?? "" }

        logInButton.reactive.pressed = CocoaAction(viewModel.loginAction)

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues {
            $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss()
        }

        disposables += viewModel.loginAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
                case .completed:
                    if SunriseTabBarController.currentlyActive?.selectedIndex == AppRouting.TabIndex.cartTab.index {
                        self?.performSegue(withIdentifier: "showCheckout", sender: self)
                        self?.navigationController?.popViewController(animated: false)
                    } else if SunriseTabBarController.currentlyActive?.selectedIndex != AppRouting.TabIndex.profileTab.index {
                        self?.navigationController?.popViewController(animated: true)
                    }
                    [self?.emailField, self?.passwordField].forEach { $0?.text = "" }
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: viewModel.failedTitle,
                            message: self?.viewModel?.alertMessage(for: [error]),
                            preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                default:
                    return
            }
        }

        disposables += logInButton.reactive.isEnabled <~ viewModel.isLoginInputValid

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}
