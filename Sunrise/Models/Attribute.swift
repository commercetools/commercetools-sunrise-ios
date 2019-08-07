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
        case ("enum", .dictionary(let value)):
            return value["label"]?.string
        case ("text", .string(let value)):
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

extension Attribute {
    static let colorValues: [String: UIColor] = ["black": UIColor.black, "grey": UIColor.gray, "beige": UIColor(red: 0.96, green: 0.96, blue: 0.86, alpha: 1.0), "white": .white, "blue": .blue, "brown": .brown, "turquoise": UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1.0), "petrol": UIColor(red: 0.09, green: 0.45, blue: 0.56, alpha: 1.0), "green": UIColor(red: 0.30, green: 0.57, blue: 0.01, alpha: 1.0), "red": .red, "purple": .purple, "pink": UIColor(red: 1.00, green: 0.75, blue: 0.80, alpha: 1.0), "orange": .orange, "yellow": .yellow, "oliv": UIColor(red: 0.50, green: 0.50, blue: 0.00, alpha: 1.0), "gold": UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1.0), "silver": UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0), "multicolored": UIColor(patternImage: #imageLiteral(resourceName: "multicolor"))]

    static let kBrandAttributeName = "designer"
    static let kColorsAttributeName = "color"
    static let kSizeAttributeName = "commonSize"
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