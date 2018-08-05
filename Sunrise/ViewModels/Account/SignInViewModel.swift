//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift

/// The key used for storing logged in username.
let kLoggedInUsername = "LoggedInUsername"

class SignInViewModel: BaseViewModel {

    // Inputs
    let username = MutableProperty("")
    let password = MutableProperty("")
    var loginAction: Action<Void, CustomerSignInResult, CTError>!

    // Outputs
    let isLoading: MutableProperty<Bool>
    let isLoginInputValid = MutableProperty(false)
    var isLoggedIn: Bool {
        return AppRouting.isLoggedIn
    }

    private let disposables = CompositeDisposable()

    // MARK: Lifecycle

    override init() {
        isLoading = MutableProperty(false)

        super.init()

        disposables += isLoginInputValid <~ username.combineLatest(with: password).map { !$0.isEmpty && !$1.isEmpty }

        loginAction = Action(enabledIf: self.isLoginInputValid) { [unowned self] _ in
            self.isLoading.value = true
            return self.login(username: self.username.value, password: self.password.value)
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Commercetools platform user log in and sign up

    private func login(username: String, password: String) -> SignalProducer<CustomerSignInResult, CTError> {
        return SignalProducer { [weak self] observer, disposable in
            Commercetools.loginCustomer(username: username, password: password,
                    activeCartSignInMode: .mergeWithExistingCustomerCart) { result in
                if let error = result.errors?.first as? CTError, result.isFailure {
                    observer.send(error: error)
                } else if let signInResult = result.model {
                    observer.send(value: signInResult)
                    observer.sendCompleted()
                    // Save username to user defaults for displaying it later on in the app
                    UserDefaults.standard.set(username, forKey: kLoggedInUsername)
                    UserDefaults.standard.synchronize()
                    AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
                    AppRouting.wishListViewController?.viewModel?.refreshObserver.send(value: ())
                    AppRouting.profileViewController?.viewModel?.refreshObserver.send(value: ())
                }
                self?.isLoading.value = false
            }
        }
    }
}
