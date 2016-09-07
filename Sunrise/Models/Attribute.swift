//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Attribute: Mappable {

    // MARK: - Properties

    var name: String?
    var value: AnyObject?

    private let dateFormatter = NSDateFormatter()

    init?(_ map: Map) {
        dateFormatter.locale = NSLocale.currentLocale()
    }

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        name               <- map["name"]
        value              <- map["value"]
    }

    // MARK: - Value string representation

    func value(type: AttributeType) -> String? {
        return representationForRawValue(value, ofType: type)
    }
    
    private func representationForRawValue(rawValue: AnyObject?, ofType type: AttributeType) -> String? {
        guard let typeName = type.name else { return nil }

        switch (typeName, rawValue) {
        case ("boolean", let rawValue as Bool):
            return rawValue ? NSLocalizedString("Yes", comment: "Yes") : NSLocalizedString("No", comment: "No")
        case (let typeName, let rawValue as String) where ["text", "enum"].contains(typeName):
            return rawValue
        case ("ltext", let rawValue as [String: String]):
            return rawValue.localizedString
        case ("lenum", let rawValue as [String: AnyObject]):
            return (rawValue["label"] as? [String: String])?.localizedString
        case ("number", let rawValue as Int):
            return String(rawValue)
        case ("number", let rawValue as Double):
            return String(rawValue)
        case ("money", let rawValue):
            return Mapper<Money>().map(rawValue)?.description
        case ("date", let rawValue):
            if let date = ISO8601DateTransform().transformFromJSON(rawValue) {
                dateFormatter.dateStyle = .MediumStyle
                dateFormatter.timeStyle = .NoStyle
                return dateFormatter.stringFromDate(date)
            }
            return nil
        case ("time", let rawValue):
            if let date = ISO8601DateTransform().transformFromJSON(rawValue) {
                dateFormatter.dateStyle = .NoStyle
                dateFormatter.timeStyle = .ShortStyle
                return dateFormatter.stringFromDate(date)
            }
            return nil
        case ("datetime", let rawValue):
            if let date = ISO8601DateTransform().transformFromJSON(rawValue) {
                dateFormatter.dateStyle = .MediumStyle
                dateFormatter.timeStyle = .ShortStyle
                return dateFormatter.stringFromDate(date)
            }
            return nil
        case ("set", let rawValues as [AnyObject]):
            if let elementType = type.elementType {
                return rawValues.reduce("") {
                    if let rawValue = self.representationForRawValue($1, ofType: elementType) {
                        return "\($0) \(rawValue)"
                    }
                    return $0
                }
            }
            return nil

        // Please note that the representation for both nested and reference types has not been added, since it is
        // highly dependable on the specific presentation use case, and UI elements.

        default: return nil

        }
    }

}