//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage
import SVProgressHUD

class LoginViewController: UIViewController {
    
    @IBInspectable var borderColor: UIColor = UIColor.lightGrayColor()
    
    @IBOutlet weak var loginFormView: UIView!
    @IBOutlet weak var registerFormView: UIView!

    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var registrationEmailField: UITextField!
    @IBOutlet weak var firstNameField: UITextField!
    @IBOutlet weak var lastNameField: UITextField!
    @IBOutlet weak var registrationPasswordField: UITextField!
    @IBOutlet weak var registrationPasswordConfirmationField: UITextField!

    private var loginAction: CocoaAction?
    private var registerAction: CocoaAction?

    private var viewModel: LoginViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        emailField.keyboardType = .EmailAddress

        [loginFormView, registerFormView].forEach {
            $0.layer.borderColor = borderColor.CGColor
        }


        [emailField, passwordField, registrationEmailField, firstNameField, lastNameField,
                registrationPasswordField, registrationPasswordConfirmationField].forEach {
            $0.layer.borderColor = borderColor.CGColor
            $0.leftView = UIView(frame: CGRectMake(0, 0, 7, $0.frame.height))
            $0.leftViewMode = .Always
        }

        viewModel = LoginViewModel()
    }

    @IBAction func logIn(sender: UIButton) {
        loginAction?.execute(nil)
    }
    
    @IBAction func register(sender: UIButton) {
        registerAction?.execute(nil)
    }
    
    
    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        loginAction = CocoaAction(viewModel.loginAction, { _ in return () })

        viewModel.username <~ emailField.signalProducer()
        viewModel.password <~ passwordField.signalProducer()
        viewModel.email <~ registrationEmailField.signalProducer()
        viewModel.firstName <~ firstNameField.signalProducer()
        viewModel.lastName <~ lastNameField.signalProducer()
        viewModel.registrationPassword <~ registrationPasswordField.signalProducer()
        viewModel.registrationPasswordConfirmation <~ registrationPasswordConfirmationField.signalProducer()

        viewModel.isLoggedIn.producer
        .observeOn(UIScheduler())
        .startWithNext({ isLoggedIn in
            if isLoggedIn {
                AppRouting.setupMyAccountRootViewController(isLoggedIn: isLoggedIn)
            }
        })

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] isLoading in
            self?.loginButton.enabled = !isLoading
            if isLoading {
                SVProgressHUD.show()
            } else {
                SVProgressHUD.dismiss()
            }
        })

        viewModel.isLoginInputValid.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] inputIsValid in
            self?.loginButton.enabled = inputIsValid
        })

        viewModel.loginAction.events
        .observeOn(UIScheduler())
        .observeNext({ [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
            case .Completed:
                AppRouting.setupMyAccountRootViewController(isLoggedIn: true)
            case let .Failed(error):
                let alertController = UIAlertController(
                        title: "Log in failed",
                        message: self?.viewModel?.alertMessageForErrors([error]),
                        preferredStyle: .Alert
                        )
                alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self?.presentViewController(alertController, animated: true, completion: nil)
            default:
                return
            }
        })
    }
    
}
