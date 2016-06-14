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
            AuthManager.sharedInstance.loginUser(username, password: password, completionHandler: { error in
                if let error = error {
                    observer.sendFailed(error)
                } else {
                    observer.sendCompleted()
                    // Save username to user defaults for displaying it later on in the app
                    NSUserDefaults.standardUserDefaults().setObject(username, forKey: kLoggedInUsername)
                    NSUserDefaults.standardUserDefaults().synchronize()
                }
                self.isLoading.value = false
            })
        }
    }

}