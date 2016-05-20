//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Money: Mappable {

    // MARK: - Properties

    var currencyCode: String?
    var centAmount: Int?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        currencyCode       <- map["currencyCode"]
        centAmount         <- map["centAmount"]
    }

}