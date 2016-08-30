//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ChannelDetails: Mappable {

    // MARK: - Properties

    var openingTimes: [String: String]?
    var imageUrl: String?
    var latitude: Double?
    var longitude: Double?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        openingTimes     <- map["fields.openingTimes"]
        imageUrl         <- map["fields.imageUrl"]
        latitude         <- map["fields.latitude"]
        longitude        <- map["fields.longitude"]
    }

}