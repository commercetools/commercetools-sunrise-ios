//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Attribute: Mappable {

    // MARK: - Properties

    var name: String?
    var value: AnyObject?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        name               <- map["name"]
        value              <- map["value"]
    }

    // MARK: - Value string representation

    func value(type: AttributeType) -> String? {
        guard let typeName = type.name else { return nil }

        switch (typeName, value) {
            case ("boolean", let value as Bool):
                return value ? NSLocalizedString("Yes", comment: "Yes") : NSLocalizedString("No", comment: "No")
            case (let typeName, let value as String) where ["text", "enum"].contains(typeName):
                return value
            case (let typeName, let value as [String: String]) where ["ltext", "lenum"].contains(typeName):
                return value.localizedString
            case ("number", let value as Int):
                return String(value)
            case ("number", let value as Double):
                return String(value)
            case ("money", let value):
                return Mapper<Money>().map(value)?.description
        
            default: return nil
        }
    }

}