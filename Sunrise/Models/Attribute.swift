//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Attribute {

    // MARK: - Value string representation

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        return dateFormatter
    }

    func value(_ type: AttributeType) -> String? {
        return representation(for: value, ofType: type)
    }

    private func representation(for rawValue: JsonValue?, ofType type: AttributeType) -> String? {
        guard let rawValue = rawValue else { return nil }
        switch (type.name, rawValue) {
        case ("boolean", .bool(let value)):
            return value ? NSLocalizedString("Yes", comment: "Yes") : NSLocalizedString("No", comment: "No")
        case (let typeName, .string(let value)) where ["text", "enum"].contains(typeName):
            return value
        case ("ltext", .dictionary(let value)):
            return localizedString(from: value)
        case ("lenum", .dictionary(let value)):
            guard let dictionary = value["label"]?.dictionary else { return nil }
            return localizedString(from: dictionary)
        case ("number", .int(let value)):
            return String(value)
        case ("number", .double(let value)):
            return String(value)
        case ("money", .dictionary(let value)):
            guard let currencyCode = value["currencyCode"]?.string, let centAmount = value["centAmount"]?.int else { return nil }
            return Money(currencyCode: currencyCode, centAmount: centAmount).description
        case ("date", .string(let value)):
            if let date = dateFormatter.date(from: value) {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                return dateFormatter.string(from: date)
            }
            return nil
        case ("time", .string(let value)):
            if let date = dateFormatter.date(from: value) {
                dateFormatter.dateStyle = .none
                dateFormatter.timeStyle = .short
                return dateFormatter.string(from: date)
            }
            return nil
        case ("datetime", .string(let value)):
            if let date = dateFormatter.date(from: value) {
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                return dateFormatter.string(from: date)
            }
            return nil
        case ("set", .array(let values)):
            if let elementType = type.elementType {
                return values.reduce("") {
                    if let rawValue = self.representation(for: $1, ofType: elementType) {
                        return "\($0 ?? "") \(rawValue)"
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

extension Attribute: Equatable {
    public static func == (lhs: Attribute, rhs: Attribute) -> Bool {
        return lhs.name == rhs.name && lhs.value == rhs.value
    }
}

extension JsonValue: Equatable {
    public static func == (lhs: JsonValue, rhs: JsonValue) -> Bool {
        switch (lhs, rhs) {
        case (.bool(let lhs), .bool(let rhs)):
            return lhs == rhs
        case (.int(let lhs), .int(let rhs)):
            return lhs == rhs
        case (.double(let lhs), .double(let rhs)):
            return lhs == rhs
        case (.string(let lhs), .string(let rhs)):
            return lhs == rhs
        case (.dictionary(let lhs), .dictionary(let rhs)):
            return lhs == rhs
        case (.array(let lhs), .array(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }
}