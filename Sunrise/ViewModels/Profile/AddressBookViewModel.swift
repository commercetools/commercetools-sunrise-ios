//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class AddressBookViewModel: BaseViewModel {
    
    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let setDefaultAddressObserver: Signal<IndexPath, NoError>.Observer
    let deleteObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let isLoading = MutableProperty(true)

    private var addresses = [Address]()
    private var defaultAddressId: String?
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    override init() {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (setDefaultAddressSignal, setDefaultAddressObserver) = Signal<IndexPath, NoError>.pipe()
        self.setDefaultAddressObserver = setDefaultAddressObserver

        let (deleteSignal, deleteObserver) = Signal<IndexPath, NoError>.pipe()
        self.deleteObserver = deleteObserver
        
        super.init()
        
        disposables += refreshSignal.observeValues { [unowned self] in self.retrieveAddresses() }
        disposables += setDefaultAddressSignal.observeValues { [unowned self] in self.setDefaultAddress(address: self.addresses[$0.item]) }
        disposables += deleteSignal.observeValues { [unowned self] in self.deleteAddress(address: self.addresses[$0.item]) }
    }
    
    deinit {
        disposables.dispose()
    }
    
    func addressViewModelForAddress(at indexPath: IndexPath) -> AddressViewModel {
        return AddressViewModel(address: addresses[indexPath.row], type: .shipping)
    }
    
    // MARK: - Data Source
    
    var numberOfAddresses: Int {
        return addresses.count
    }

    func addressName(at indexPath: IndexPath) -> String? {
        let address = addresses[indexPath.item]
        var name = ""
        name += address.title != nil ? "\(address.title!) " : ""
        name += address.firstName != nil ? "\(address.firstName!) " : ""
        name += address.lastName ?? ""
        return name
    }

    func addressDetails(at indexPath: IndexPath) -> String? {
        let address = addresses[indexPath.item]
        return address.description
    }

    func isAddressDefault(at indexPath: IndexPath) -> Bool {
        return addresses[indexPath.item].id == defaultAddressId
    }
    
    // MARK: - Addresses management
    
    private func retrieveAddresses() {
        isLoading.value = true
        customerProfile { profile in
            if let profile = profile {
                self.addresses = profile.addresses.filter({ profile.billingAddressIds?.contains($0.id ?? "") == false })
                self.defaultAddressId = profile.defaultShippingAddressId
                // Default address should be the first in the list if it exists
                if let index = self.addresses.firstIndex(where: { $0.id == self.defaultAddressId }), self.defaultAddressId != nil {
                    let defaultAddress = self.addresses.remove(at: index)
                    self.addresses.insert(defaultAddress, at: 0)
                }
            }
            self.isLoading.value = false
        }
    }

    private func setDefaultAddress(address: Address) {
        let actions = [CustomerUpdateAction.setDefaultShippingAddress(addressId: address.id)]
        updateCustomer(actions: actions)
    }

    private func deleteAddress(address: Address) {
        guard let addressId = address.id else { return }
        let actions = [CustomerUpdateAction.removeAddress(addressId: addressId)]
        updateCustomer(actions: actions)
    }

    private func updateCustomer(actions: [CustomerUpdateAction]) {
        isLoading.value = true
        customerProfile { profile in
            if let profile = profile {
                let updateActions = UpdateActions(version: profile.version, actions: actions)
                Customer.update(actions: updateActions) { result in
                    if let profile = result.model {
                        self.addresses = profile.addresses.filter({ profile.billingAddressIds?.contains($0.id ?? "") == false })
                        self.defaultAddressId = profile.defaultShippingAddressId
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                }
            } else {
                self.isLoading.value = false
            }
        }
    }

    private func customerProfile(_ completion: @escaping (Customer?) -> Void) {
        Customer.profile { result in
            if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            completion(result.model)
        }
    }
}
