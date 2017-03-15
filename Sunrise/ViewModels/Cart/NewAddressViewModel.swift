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

    private var disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        super.init()

        retrieveCountries()
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Customer addresses retrieval

    private func retrieveCountries() {
        isLoading.value = true

    }

    private func saveNewAddress() {
        var address = Address()
        address.title = title.value
        address.firstName = firstName.value
        address.lastName = lastName.value
        address.streetName = address1.value
        address.additionalAddressInfo = address2.value
        address.postalCode = postCode.value
        address.city = city.value
        address.region = region.value
        address.country = country.value

        Customer.profile { result in
            if let profile = result.model, let version = profile.version, result.isSuccess {
                var options = AddAddressOptions()
                options.address = address
                let updateActions = UpdateActions<CustomerUpdateAction>(version: version, actions: [.addAddress(options: options)])
                Customer.update(actions: updateActions, result: { result in
                    // continue
                })
            }
        }
    }
}
