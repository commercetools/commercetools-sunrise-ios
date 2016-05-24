//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ProductVariantAvailability: Mappable {

    // MARK: - Properties

    var isOnStock: Bool?
    var restockableInDays: Int?
    var availableQuantity: Int?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        isOnStock                <- map["isOnStock"]
        restockableInDays        <- map["restockableInDays"]
        availableQuantity        <- map["availableQuantity"]
    }



}