//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ChannelDetails: Mappable {

    // MARK: - Properties

    var city: String?
    var zip: String?
    var street: String?
    var number: String?
    var country: String?
    var openLine1: String?
    var openLine2: String?
    var imageUrl: String?
    var lat: Double?
    var lon: Double?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        city             <- map["fields.city"]
        zip              <- map["fields.zip"]
        street           <- map["fields.street"]
        number           <- map["fields.number"]
        country          <- map["fields.country"]
        openLine1        <- map["fields.openLine1"]
        openLine2        <- map["fields.openLine2"]
        imageUrl         <- map["fields.imageUrl"]
        lat              <- map["fields.lat"]
        lon              <- map["fields.lon"]
    }

}