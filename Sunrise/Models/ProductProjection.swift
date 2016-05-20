//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ProductProjection: Mappable {

    // MARK: - Properties

    var id: String?
    var name: [String: String]?
    var masterVariant: ProductVariant?
    var variants: [ProductVariant]?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id                 <- map["id"]
        name               <- map["name"]
        masterVariant      <- map["masterVariant"]
        variants           <- map["variants"]
    }

}