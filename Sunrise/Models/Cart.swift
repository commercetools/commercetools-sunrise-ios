//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Cart: Mappable {

    // MARK: - Properties

    var id: String?
    var version: UInt?
    var createdAt: NSDate?
    var lastModifiedAt: NSDate?
    var lineItems: [LineItem]?
    var country: String?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id               <- map["id"]
        version          <- map["version"]
        createdAt        <- (map["createdAt"], DateTransform())
        lastModifiedAt   <- (map["lastModifiedAt"], DateTransform())
        lineItems        <- map["lineItems"]
        country          <- map["country"]
    }

}