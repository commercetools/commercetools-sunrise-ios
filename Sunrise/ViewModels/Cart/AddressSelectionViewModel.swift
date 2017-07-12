//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class AddressSelectionViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let selectedIndexPathObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let isLoading = MutableProperty(false)
    let performSegueSignal: Signal<Void, NoError>

    private var defaultAddress: MutableProperty<Address?> = MutableProperty(nil)
    private var addresses: MutableProperty<[Address]> = MutableProperty([Address]())
    private let performSegueObserver: Signal<Void, NoError>.Observer
    private let currentLocale = NSLocale.init(localeIdentifier: NSLocale.current.identifier)
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(customer: Customer? = nil) {
        (performSegueSignal, performSegueObserver) = Signal<Void, NoError>.pipe()

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedIndexPathObserver = selectedIndexPathObserver

        super.init()

        disposables += refreshSignal.observeValues { [weak self] in
            self?.retrieveAddresses()
        }

        disposables += selectedIndexPathSignal.observeValues { [weak self] selectedIndexPath in
            self?.addAddressToCart(at: selectedIndexPath)
        }

        if let customer = customer {
            updateAddresses(for: customer)
        } else {
            retrieveAddresses()
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    enum CellType {
        case addNew
        case address
    }

    var numberOfSections: Int {
        return defaultAddress.value == nil ? 1 : 2
    }

    func title(for section: Int) -> String {
        return numberOfSections == 2 && section == 0 ? NSLocalizedString("Default Shipping Address", comment: "Default Shipping Address") : NSLocalizedString("Saved Addresses", comment: "Saved Addresses")
    }

    func numberOfRows(in section: Int) -> Int {
        return section == 0 && defaultAddress.value != nil ? 1 : addresses.value.count + 1
    }

    func cellType(at indexPath: IndexPath) -> CellType {
        return indexPath.section == numberOfSections - 1 && indexPath.row == numberOfRows(in: indexPath.section) - 1 ? .addNew : .address
    }

    func firstName(at indexPath: IndexPath) -> String? {
        let address = indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value : addresses.value[indexPath.row]
        if let title = address?.title, title != "" {
            return "\(title) \(address?.firstName ?? "")"
        }
        return address?.firstName
    }

    func lastName(at indexPath: IndexPath) -> String? {
        return indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.lastName : addresses.value[indexPath.row].lastName
    }

    func streetName(at indexPath: IndexPath) -> String? {
        if indexPath.section == 0 && defaultAddress.value != nil {
            return (defaultAddress.value?.streetName ?? "") + " " + (defaultAddress.value?.additionalStreetInfo ?? "")
        } else {
            return (addresses.value[indexPath.row].streetName ?? "") + " " + (addresses.value[indexPath.row].additionalStreetInfo ?? "")
        }
    }

    func city(at indexPath: IndexPath) -> String? {
        return indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.city : addresses.value[indexPath.row].city
    }

    func postalCode(at indexPath: IndexPath) -> String? {
        return indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.postalCode : addresses.value[indexPath.row].postalCode
    }

    func region(at indexPath: IndexPath) -> String? {
        return indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.region : addresses.value[indexPath.row].region
    }

    func country(at indexPath: IndexPath) -> String? {
        guard let countryCode = indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.country : addresses.value[indexPath.row].country else { return nil }
        return currentLocale.displayName(forKey: NSLocale.Key.countryCode, value: countryCode) ?? countryCode
    }

    func isDefault(at indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 && defaultAddress.value != nil
    }

    // MARK: - Customer addresses

    private func retrieveAddresses() {
        isLoading.value = true

        Customer.profile { result in
            if let customer = result.model, result.isSuccess {
                self.updateAddresses(for: customer)

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }

    private func updateAddresses(for customer: Customer) {
        defaultAddress.value = customer.addresses.filter({ return $0.id == customer.defaultShippingAddressId }).first
        addresses.value = customer.addresses.filter({ $0.id != defaultAddress.value?.id })
    }

    private func addAddressToCart(at indexPath: IndexPath) {
        guard cellType(at: indexPath) == .address else { return }
        isLoading.value = true
        let address = indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value! : addresses.value[indexPath.row]

        Cart.active { result in
            if let cart = result.model, result.isSuccess {
                let updateActions = UpdateActions<CartUpdateAction>(version: cart.version, actions: [.setShippingAddress(address: address), .setBillingAddress(address: address)])
                Cart.update(cart.id, actions: updateActions, result: { result in
                    if result.isSuccess {
                        self.performSegueObserver.send(value: ())
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
