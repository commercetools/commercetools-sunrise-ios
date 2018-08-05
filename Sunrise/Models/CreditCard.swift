//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation

/**
    Model for storing credit card information.
    NOTE: As this struct is being encoded and decoded to and from keychain, changing any properties will require migration
    in `CreditCardStore`.
*/
struct CreditCard: Codable {
    let id: String
    let name: String
    let number: String
    let ccv: String
    let validMonth: String
    let validYear: String
    var isDefault: Bool
}