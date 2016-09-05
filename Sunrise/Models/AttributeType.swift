//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct AttributeType: Mappable {

    // MARK: - Properties

    var name: String?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        name               <- map["name"]
    }

}