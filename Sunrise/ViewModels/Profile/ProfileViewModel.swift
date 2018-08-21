//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import AWSS3

class ProfileViewModel: BaseViewModel {
    
    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let deleteProfilePhotoObserver: Signal<Void, NoError>.Observer
    let logoutObserver: Signal<Void, NoError>.Observer
    
    // Outputs
    let helloCustomer = MutableProperty("")
    let isLoginHidden = MutableProperty(Commercetools.authState == .customerToken)
    let profilePhoto = MutableProperty<UIImage?>(nil)

    weak var signInViewModel: SignInViewModel? {
        didSet {
            bindSignInViewModel()
        }
    }
    private let profile: MutableProperty<Customer?> = MutableProperty(nil)
    private let transferUtility = AWSS3TransferUtility.default()
    private let s3Service = AWSS3.default()
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    init(customer: Customer? = nil) {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (logoutSignal, logoutObserver) = Signal<Void, NoError>.pipe()
        self.logoutObserver = logoutObserver
        
        let (deleteProfilePhotoSignal, deleteProfilePhotoObserver) = Signal<Void, NoError>.pipe()
        self.deleteProfilePhotoObserver = deleteProfilePhotoObserver

        super.init()

        disposables += isLoginHidden <~ profile.map { _ in Commercetools.authState == .customerToken }
        
        disposables += helloCustomer <~ profile.map { $0 == nil ? NSLocalizedString("Welcome back", comment: "Welcome back") : String(format: NSLocalizedString("Hey %@", comment: "Hey to Customer"), $0?.firstName ?? "") }
        
        disposables += refreshSignal.observeValues { [unowned self] in self.retrieveProfile() }
        
        disposables += logoutSignal.observeValues { [unowned self] in
            Commercetools.logoutCustomer()
            AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
            AppRouting.wishListViewController?.viewModel?.refreshObserver.send(value: ())
            self.isLoginHidden.value = Commercetools.authState == .customerToken
        }
        
        disposables += profilePhoto <~ deleteProfilePhotoSignal.map { nil }
        
        disposables += deleteProfilePhotoSignal
        .observe(on: QueueScheduler())
        .observeValues { [unowned self] in
            guard let deleteObjectRequest = AWSS3DeleteObjectRequest(), let customerId = self.profile.value?.id else { return }
            deleteObjectRequest.bucket = "commercetools-sunrise"
            deleteObjectRequest.key = "customers/profile-photos/\(customerId).png"
            self.s3Service.deleteObject(deleteObjectRequest).continueWith { task in
                if let error = task.error {
                    debugPrint(error)
                }
                return nil
            }
        }
        
        disposables += profile.producer
        .observe(on: QueueScheduler())
        .filter { $0 != nil }
        .startWithValues { [unowned self] in
            self.transferUtility.downloadData(fromBucket: "commercetools-sunrise", key: "customers/profile-photos/\($0!.id).png", expression: nil, completionHandler: { _, _, data, error in
                if let data = data, error == nil {
                    self.profilePhoto.value = UIImage(data: data)
                }
            }).continueWith { _ in return nil }
        }

        if Commercetools.authState == .customerToken {
            retrieveProfile()
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
