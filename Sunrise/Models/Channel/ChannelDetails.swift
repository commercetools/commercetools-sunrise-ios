//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ChannelDetails: Mappable {

    // MARK: - Properties

    var openLine1: String?
    var openLine2: String?
    var imageUrl: String?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        openLine1        <- map["fields.openLine1"]
        openLine2        <- map["fields.openLine2"]
        imageUrl         <- map["fields.imageUrl"]
    }

}