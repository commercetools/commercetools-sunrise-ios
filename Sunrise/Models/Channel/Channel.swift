//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ObjectMapper

class Channel: Mappable {

    // MARK: - Properties

    var id: String?
    var version: UInt?
    var createdAt: NSDate?
    var lastModifiedAt: NSDate?
    var key: String?
    var name: [String: String]?
    var description: [String: String]?
    var details: ChannelDetails?

    required init?(_ map: Map) {}

    // MARK: - Mappable

    func mapping(map: Map) {
        id               <- map["id"]
        version          <- map["version"]
        createdAt        <- (map["createdAt"], DateTransform())
        lastModifiedAt   <- (map["lastModifiedAt"], DateTransform())
        key              <- map["key"]
        name             <- map["name"]
        description      <- map["description"]
        details          <- map["custom"]
    }

}

extension Channel: QueryEndpoint {

    static let path = "channels"

}