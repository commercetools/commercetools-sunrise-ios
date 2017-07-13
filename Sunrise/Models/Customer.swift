//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Customer {

    var customType: [String: Any]? {
        return custom?["type"] as? [String: Any]
    }

    // MARK: - Helper method making it more easier to add necessary `iOSUser` customer custom type

    static func addCustomTypeIfNotExists(_ completionHandler: @escaping (UInt?, [Error]?) -> Void) {
        Customer.profile { result in
            if let customerVersion = result.model?.version, result.isSuccess && result.model?.customType == nil {
                // Custom type not present, add it
                let type = ResourceIdentifier(typeId: "type", key: "iOSUser")
                let updateActions = UpdateActions(version: customerVersion, actions: [CustomerUpdateAction.setCustomType(type: type, fields: nil)])
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