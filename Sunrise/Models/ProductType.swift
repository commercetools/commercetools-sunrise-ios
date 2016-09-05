//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ProductType: Mappable {
    
    // MARK: - Properties
    
    var id: String?
    var version: UInt?
    var createdAt: NSDate?
    var lastModifiedAt: NSDate?
    var key: String?
    var name: String?
    var description: String?
    var attributes: [AttributeDefinition]?

    init?(_ map: Map) {}
    
    // MARK: - Mappable
    
    mutating func mapping(map: Map) {
        id                 <- map["id"]
        version            <- map["version"]
        createdAt          <- (map["createdAt"], DateTransform())
        lastModifiedAt     <- (map["lastModifiedAt"], DateTransform())
        key                <- map["key"]
        name               <- map["name"]
        description        <- map["description"]
        attributes         <- map["attributes"]
    }
    
}