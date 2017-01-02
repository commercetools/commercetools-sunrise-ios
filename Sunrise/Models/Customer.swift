//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Customer {

    // Customer address used when making a reservation
    var reservationAddress: Address {
        var address = addresses?.filter({ $0.id == defaultBillingAddressId }).first ?? Address()
        address.firstName = firstName
        address.lastName = lastName
        return address
    }

    var customType: [String: Any]? {
        return custom?["type"] as? [String: Any]
    }

    // MARK: - Helper method making it more easier to add necessary `iOSUser` customer custom type

    static func addCustomTypeIfNotExists(_ completionHandler: @escaping (UInt?, [Error]?) -> Void) {
        Customer.profile { result in
            if let customerVersion = result.model?.version, result.isSuccess && result.model?.customType == nil {
                // Custom type not present, add it
                var options = SetCustomTypeOptions()
                var type = ResourceIdentifier()
                type.key = "iOSUser"
                type.typeId = "type"
                options.type = type
                let updateActions = UpdateActions<CustomerUpdateAction>(version: customerVersion, actions: [.setCustomType(options: options)])
                Customer.update(actions: updateActions) { result in
                    completionHandler(result.model?.version, result.errors)
                }

            } else {
                // Custom type is present, or the operation failed
                completionHandler(result.model?.version, result.errors)
            }
        }
    }

    // MARK: - My store

    private var fields: [String: Any]? {
        return custom?["fields"] as? [String: Any]
    }
    var myStore: Reference<Channel>? {
        if let myStoreJSON = fields?["myStore"] as? [String: Any] {
            return Reference<Channel>(JSON: myStoreJSON)
        }
        return nil
    }
}