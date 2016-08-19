//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveCocoa

/// The key used for storing logged in username.
let kLoggedInUsername = "LoggedInUsername"

class LoginViewModel: BaseViewModel {

    // Inputs
    let username = MutableProperty("")
    let password = MutableProperty("")

    // Outputs
    let isLoggedIn: MutableProperty<Bool>
    let isLoading: MutableProperty<Bool>
    let inputIsValid = MutableProperty(false)

    // Actions
    lazy var loginAction: Action<Void, Void, NSError> = { [unowned self] in
        return Action(enabledIf: self.inputIsValid, { _ in
            self.isLoading.value = true
            return self.loginUser(self.username.value, password: self.password.value)
        })
    }()

    // MARK: Lifecycle

    override init() {
        isLoggedIn = MutableProperty(AuthManager.sharedInstance.state == .CustomerToken)
        isLoading = MutableProperty(false)

        super.init()

        inputIsValid <~ username.producer.combineLatestWith(password.producer).map { (username, password) in
            username.characters.count > 0 && password.characters.count > 0
        }
    }

    // MARK: - Commercetools platform user log in

    private func loginUser(username: String, password: String) -> SignalProducer<Void, NSError> {
        return SignalProducer { observer, disposable in
            AuthManager.sharedInstance.loginUser(username, password: password, completionHandler: { [weak self] error in
                if let error = error {
                    observer.sendFailed(error)
                } else {
                    observer.sendCompleted()
                    self?.sendUserMetricsToPushTech()
                    // Save username to user defaults for displaying it later on in the app
                    NSUserDefaults.standardUserDefaults().setObject(username, forKey: kLoggedInUsername)
                    NSUserDefaults.standardUserDefaults().synchronize()
                }
                self?.isLoading.value = false
            })
        }
    }

    private func sendUserMetricsToPushTech() {
        Commercetools.Customer.profile({ result in
            if let response = result.response where result.isSuccess {

                if let userId = response["id"] as? String {
                    PSHMetrics.sendMetricUserID(userId)
                }

                if let email = response["email"] as? String {
                    PSHMetrics.sendMetricEmail(email)
                }

                if let firstName = response["firstName"] as? String {
                    PSHMetrics.sendMetricFirstName(firstName)
                }

                if let lastName = response["lastName"] as? String {
                    PSHMetrics.sendMetricLastName(lastName)
                }

                PSHMetrics.forceSendMetrics()
            }
        })
    }

}