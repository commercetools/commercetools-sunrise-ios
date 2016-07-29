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
    var address: Address?

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
        address          <- map["address"]
        details          <- map["custom"]
    }

}

extension Channel: QueryEndpoint {

    static let path = "channels"

}

extension Channel: Hashable {

    var hashValue: Int {
        return (id ?? "").hashValue
    }

}

func ==(lhs: Channel, rhs: Channel) -> Bool {
    return lhs.hashValue == rhs.hashValue
}