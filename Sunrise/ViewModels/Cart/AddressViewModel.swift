//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class AddressViewModel: BaseViewModel {

    // Inputs
    let firstName: MutableProperty<String?> = MutableProperty(nil)
    let lastName: MutableProperty<String?> = MutableProperty(nil)
    let phone: MutableProperty<String?> = MutableProperty(nil)
    let address1: MutableProperty<String?> = MutableProperty(nil)
    let address2: MutableProperty<String?> = MutableProperty(nil)
    let city: MutableProperty<String?> = MutableProperty(nil)
    let postCode: MutableProperty<String?> = MutableProperty(nil)
    let country: MutableProperty<String?> = MutableProperty(nil)
    let state: MutableProperty<String?> = MutableProperty(nil)
    var saveAction: Action<Void, Void, CTError>!

    // Outputs
    let title: MutableProperty<String?> = MutableProperty(nil)
    let isLoading = MutableProperty(false)
    let isStateEnabled = MutableProperty(false)
    let countries = MutableProperty([String: String]())
    let isAddressValid = MutableProperty(false)

    // Title components
    let billing = NSLocalizedString("billing", comment: "billing")
    let delivery = NSLocalizedString("delivery", comment: "delivery")

    var address: Address?

    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(address: Address? = nil, type: CheckoutViewModel.AddressType) {
        self.address = address

        if address == nil {
            self.title.value = String(format: NSLocalizedString("Add %@ address", comment: "Add new address"), type == .shipping ? delivery : billing)//NSLocalizedString("Add new %@ address", comment: "Add new address", type == .shipping ? delivery : billing)
        } else {
            self.title.value = String(format: NSLocalizedString("Edit %@ address", comment: "Edit address"), type == .shipping ? delivery : billing)
        }

        firstName.value = address?.firstName
        lastName.value = address?.lastName
        phone.value = address?.phone
        address1.value = address?.streetName
        address2.value = address?.additionalStreetInfo
        city.value = address?.city
        postCode.value = address?.postalCode
        state.value = address?.state

        super.init()
        retrieveCountries()

        disposables += isAddressValid <~ SignalProducer.combineLatest(firstName.producer, lastName.producer, address1.producer,
                city.producer, postCode.producer, state.producer, country.producer).map { let (firstName, lastName, address, city, postCode, state, country) = $0
            if country?.lowercased() == "us" && (state == nil || state?.isEmpty == true) {
                return false
            }
            var isRegisterInputValid = true
            [firstName, lastName, address, city, postCode, country].forEach {
                if $0 == nil || $0?.isEmpty == true {
                    isRegisterInputValid = false
                }
            }
            return isRegisterInputValid
        }

        disposables += isStateEnabled <~ country.map { [unowned self] in self.countries.value[$0 ?? ""]?.lowercased() == "us" }

        saveAction = Action(enabledIf: isAddressValid) { [unowned self] _ in
            self.isLoading.value = true
            return self.saveAddress()
        }
    }

    deinit {
        disposables.dispose()
    }

    private func saveAddress() -> SignalProducer<Void, CTError> {
        return SignalProducer { [unowned self] observer, disposable in
            DispatchQueue.global().async {
                guard let countryDisplayValue = self.country.value, let countryCode = self.countries.value[countryDisplayValue] else {
                    observer.sendCompleted()
                    return
                }
                if self.address == nil {
                    self.address = Address(country: countryCode)
                }
                guard var address = self.address else { return }
                address.firstName = self.firstName.value
                address.lastName = self.lastName.value
                address.phone = self.phone.value
                address.streetName = self.address1.value
                address.additionalStreetInfo = self.address2.value
                address.city = self.city.value
                address.postalCode = self.postCode.value
                address.country = countryCode
                address.state = self.state.value

                let semaphore = DispatchSemaphore(value: 0)
                Cart.active { result in
                    if let cart = result.model, result.isSuccess {
                        var actions = [CartUpdateAction]()
                        if let shippingAddressId = cart.shippingAddress?.id, shippingAddressId == address.id {
                            actions.append(.setShippingAddress(address: address))
                        }
                        if let billingAddressId = cart.billingAddress?.id, billingAddressId == address.id {
                            actions.append(.setBillingAddress(address: address))
                        }
                        if actions.isEmpty, !self.isAuthenticated {
                            actions += [.setShippingAddress(address: address), .setBillingAddress(address: address)]
                        }
                        let updateActions = UpdateActions(version: cart.version, actions: actions)
                        Cart.update(cart.id, actions: updateActions) { result in
                            if let error = result.errors?.first as? CTError, result.isFailure {
                                observer.send(error: error)
                            }
                            semaphore.signal()
                        }
                    } else if let error = result.errors?.first as? CTError, result.isFailure {
                        observer.send(error: error)
                        semaphore.signal()
                    }
                }
                _ = semaphore.wait(timeout: .distantFuture)

                if self.isAuthenticated {
                    Customer.profile { result in
                        if let profile = result.model, result.isSuccess {
                            var actions = [CustomerUpdateAction]()
                            if let addressId = address.id, profile.addresses.first(where: { $0.id == addressId }) != nil {
                                actions.append(.changeAddress(addressId: addressId, address: address))
                            } else {
                                actions.append(.addAddress(address: address))
                            }
                            let updateActions = UpdateActions(version: profile.version, actions: actions)
                            Customer.update(actions: updateActions) { result in
                                self.isLoading.value = false
                                if let error = result.errors?.first as? CTError, result.isFailure {
                                    observer.send(error: error)
                                } else {
                                    observer.send(value: ())
                                }
                                self.isLoading.value = false
                                observer.sendCompleted()
                            }
                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            self.isLoading.value = false
                            observer.send(error: error)
                            observer.sendCompleted()
                        }
                    }
                } else {
                    self.isLoading.value = false
                    observer.send(value: ())
                    observer.sendCompleted()
                }
            }
        }
    }

    private func retrieveCountries() {
        isLoading.value = true

        Commercetools.Project.settings { result in
            if let countries = result.model?.countries, result.isSuccess {
                var countryCodes = [String: String]()
                countries.forEach {
                    let displayName = (Locale.current as NSLocale).displayName(forKey: NSLocale.Key.countryCode, value: $0) ?? ""
                    countryCodes[displayName] = $0
                    if self.address?.country == $0 {
                        self.country.value = displayName
                    }
                }
                self.countries.value = countryCodes
            }
            self.isLoading.value = false
        }
    }

}
