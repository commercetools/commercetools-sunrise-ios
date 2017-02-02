//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ObjectMapper

extension Attribute {

    // MARK: - Value string representation

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.current
        return dateFormatter
    }

    func value(_ type: AttributeType) -> String? {
        return representation(for: value, ofType: type)
    }

    private func representation(for rawValue: Any?, ofType type: AttributeType) -> String? {
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
            return Mapper<Money>().map(JSONObject: rawValue)?.description
        case ("date", let rawValue):
            if let date = Commercetools.ISO8601DateTransform().transformFromJSON(rawValue) {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                return dateFormatter.string(from: date)
            }
            return nil
        case ("time", let rawValue):
            if let date = Commercetools.ISO8601DateTransform().transformFromJSON(rawValue) {
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .short
                return dateFormatter.string(from: date)
            }
            return nil
        case ("datetime", let rawValue):
            if let date = Commercetools.ISO8601DateTransform().transformFromJSON(rawValue) {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                return dateFormatter.string(from: date)
            }
            return nil
        case ("set", let rawValues as [AnyObject]):
            if let elementType = type.elementType {
                return rawValues.reduce("") {
                    if let rawValue = self.representation(for: $1, ofType: elementType) {
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
