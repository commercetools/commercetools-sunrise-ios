//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Order: Mappable {

    // MARK: - Properties

    var id: String?
    var version: UInt?
    var orderNumber: String?
    var createdAt: NSDate?
    var lastModifiedAt: NSDate?
    var lineItems: [LineItem]?
    var totalPrice: Money?
    var taxedPrice: TaxedPrice?
    var country: String?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id               <- map["id"]
        version          <- map["version"]
        orderNumber      <- map["orderNumber"]
        createdAt        <- (map["createdAt"], DateTransform())
        lastModifiedAt   <- (map["lastModifiedAt"], DateTransform())
        lineItems        <- map["lineItems"]
        totalPrice       <- map["totalPrice"]
        taxedPrice       <- map["taxedPrice"]
        country          <- map["country"]
    }

}