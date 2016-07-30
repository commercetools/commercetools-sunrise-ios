//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Address: Mappable {

    // MARK: - Properties

    var city: String?
    var postalCode: String?
    var streetName: String?
    var streetNumber: String?
    var country: String?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        city             <- map["city"]
        postalCode       <- map["postalCode"]
        streetName       <- map["streetName"]
        streetNumber     <- map["streetNumber"]
        country          <- map["country"]
    }

}