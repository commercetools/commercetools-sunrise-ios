//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ProductVariant: Mappable {

    // MARK: - Properties

    var id: String?
    var sku: String?
    var prices: [Price]?
    var attributes: [Attribute]?
    var images: [Image]?
    var availability: ProductVariantAvailability?
    var isMatchingVariant: Bool?
    /// The price without channel, customerGroup, country and validUntil/validFrom
    var independentPrice: Price? {
        return prices?.filter({ price in
            if price.channel == nil && price.customerGroup == nil && price.country == nil
                    && price.validFrom == nil && price.validUntil == nil {
                return true
            }
            return false
        }).first
    }

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id                 <- map["id"]
        sku                <- map["sku"]
        prices             <- map["prices"]
        attributes         <- map["attributes"]
        images             <- map["images"]
        availability       <- map["availability"]
        isMatchingVariant  <- map["isMatchingVariant"]
    }

}
