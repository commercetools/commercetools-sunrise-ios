//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class NewAddressViewModel: BaseViewModel {

    // Inputs
    let title = MutableProperty("")
    let firstName = MutableProperty("")
    let lastName = MutableProperty("")
    let address1 = MutableProperty("")
    let address2 = MutableProperty("")
    let city = MutableProperty("")
    let postCode = MutableProperty("")
    let country = MutableProperty("")
    let region = MutableProperty("")
    let phone = MutableProperty("")
    let email = MutableProperty("")

    // Outputs
    let isLoading = MutableProperty(false)
    let isAddressInputValid = MutableProperty(false)
    let countries = MutableProperty([String: String]())
    let validationErrorSignal: Signal<Void, NoError>
    let performSegueSignal: Signal<Void, NoError>

    let errorTitle = NSLocalizedString("Error", comment: "Error")
    let formGuide = NSLocalizedString("All mandatory fields (*) have to be filled", comment: "Address form instructions")

    lazy var continueCheckoutAction: Action<Void, Void, CTError> = { [unowned self] in
        return Action(enabledIf: Property(value: true)) { [unowned self] _ in
            if self.isAddressInputValid.value {
                self.saveNewAddress()
            } else {
                self.validationErrorObserver.send(value: ())
            }
            return SignalProducer.empty
        }
    }()

    private let disposables = CompositeDisposable()
    private let performSegueObserver: Signal<Void, NoError>.Observer
    private let validationErrorObserver: Signal<Void, NoError>.Observer

    // MARK: - Lifecycle

    override init() {
        (performSegueSignal, performSegueObserver) = Signal<Void, NoError>.pipe()
        (validationErrorSignal, validationErrorObserver) = Signal<Void, NoError>.pipe()

        super.init()

        isAddressInputValid <~ SignalProducer.combineLatest(firstName.producer, lastName.producer, address1.producer,
                city.producer, postCode.producer, country.producer, email.producer).map { let (firstName, lastName, address, city, postCode, country, email) = $0
            var isRegisterInputValid = true
            [firstName, lastName, address, city, postCode, country, email].forEach {
                if $0.characters.count == 0 {
                    isRegisterInputValid = false
                }
            }
            return isRegisterInputValid
        }

        retrieveCountries()
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Customer addresses retrieval

    private func retrieveCountries() {
        isLoading.value = true

        Commercetools.Project.settings { result in
            if let countries = result.model?.countries, result.isSuccess {
                var countryCodes = [String: String]()
                let locale = NSLocale.init(localeIdentifier: NSLocale.current.identifier)
                countries.forEach {
                    countryCodes[locale.displayName(forKey: NSLocale.Key.countryCode, value: $0) ?? ""] = $0
                }
                self.countries.value = countryCodes
            }
        }
    }

    private func saveNewAddress() {
        let address = Address(title: title.value, firstName: firstName.value, lastName: lastName.value, streetName: address1.value, city: city.value, region: region.value, postalCode: postCode.value, additionalStreetInfo: address2.value, country: countries.value[country.value] ?? "")

        Cart.active { result in
            if let cart = result.model, result.isSuccess {
                let updateActions = UpdateActions<CartUpdateAction>(version: cart.version, actions: [.setShippingAddress(address: address), .setBillingAddress(address: address)])
                Cart.update(cart.id, actions: updateActions, result: { result in
                    if result.isSuccess {
                        Customer.profile { result in
                            if let profile = result.model, result.isSuccess {
                                let updateActions = UpdateActions<CustomerUpdateAction>(version: profile.version, actions: [.addAddress(address: address)])
                                Customer.update(actions: updateActions) { _ in
                                    self.performSegueObserver.send(value: ())
                                }
                            } else {
                                self.performSegueObserver.send(value: ())
                            }
                        }
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
        }
    }
}
