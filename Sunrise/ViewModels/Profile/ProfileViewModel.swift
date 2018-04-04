//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class ProfileViewModel: BaseViewModel {
    
    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let logoutObserver: Signal<Void, NoError>.Observer
    
    // Outputs
    let isLoginHidden = MutableProperty(Commercetools.authState == .customerToken)

    weak var signInViewModel: SignInViewModel? {
        didSet {
            bindSignInViewModel()
        }
    }
    private let profile: MutableProperty<Customer?> = MutableProperty(nil)
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    init(customer: Customer? = nil) {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (logoutSignal, logoutObserver) = Signal<Void, NoError>.pipe()
        self.logoutObserver = logoutObserver

        super.init()

        disposables += isLoginHidden <~ profile.map { _ in Commercetools.authState == .customerToken }
        disposables += refreshSignal.observeValues { [unowned self] in self.retrieveProfile() }
        disposables += logoutSignal.observeValues { [unowned self] in
            Commercetools.logoutCustomer()
            AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
            AppRouting.wishListViewController?.viewModel?.refreshObserver.send(value: ())
            self.isLoginHidden.value = Commercetools.authState == .customerToken
        }
    }

    deinit {
        disposables.dispose()
    }

    func bindSignInViewModel() {
        guard let signInViewModel = signInViewModel else { return }
        disposables += profile <~ signInViewModel.loginAction.values.map { $0.customer }
    }

    // MARK: - Profile retrieval

    private func retrieveProfile() {
        Customer.profile { result in
            self.profile.value = result.model
        }
    }
}
