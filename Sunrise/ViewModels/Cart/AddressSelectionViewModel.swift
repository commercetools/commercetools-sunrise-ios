//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class AddressSelectionViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let selectedIndexPathObserver: Observer<IndexPath, NoError>

    // Outputs
    let isLoading = MutableProperty(false)

    private var defaultAddress: MutableProperty<Address?> = MutableProperty(nil)
    private var addresses: MutableProperty<[Address]> = MutableProperty([Address]())
    private var disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
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

        retrieveAddresses()
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

    func title(at indexPath: IndexPath) -> String? {
        return indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.title : addresses.value[indexPath.row].title
    }

    func firstName(at indexPath: IndexPath) -> String? {
        return indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value?.firstName : addresses.value[indexPath.row].firstName
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
        return NSLocale.init(localeIdentifier: NSLocale.current.identifier).displayName(forKey: NSLocale.Key.countryCode, value: countryCode) ?? countryCode
    }

    func isDefault(at indexPath: IndexPath) -> Bool {
        return indexPath.section == 0 && defaultAddress.value != nil
    }

    // MARK: - Customer addresses

    private func retrieveAddresses() {
        isLoading.value = true

        Customer.profile { result in
            if let profile = result.model, result.isSuccess {
                self.defaultAddress.value = profile.addresses?.filter({ return $0.id == profile.defaultShippingAddressId }).first
                self.addresses.value = profile.addresses?.filter({ $0.id != self.defaultAddress.value?.id }) ?? []

            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            self.isLoading.value = false
        }
    }

    private func addAddressToCart(at indexPath: IndexPath) {
        guard cellType(at: indexPath) == .address else { return }
        isLoading.value = true
        let address = indexPath.section == 0 && defaultAddress.value != nil ? defaultAddress.value! : addresses.value[indexPath.row]

        Cart.active { result in
            if let cart = result.model, let id = cart.id, let version = cart.version, result.isSuccess {
                var shippingOptions = SetShippingAddressOptions()
                shippingOptions.address = address
                var billingOptions = SetBillingAddressOptions()
                billingOptions.address = address
                let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.setShippingAddress(options: shippingOptions), .setBillingAddress(options: billingOptions)])
                Cart.update(id, actions: updateActions, result: { result in
                    if result.isSuccess {
                        // continue
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            }
        }
    }
}
