//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct Money: Mappable {

    // MARK: - Properties

    var currencyCode: String?
    var centAmount: Int?

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        currencyCode       <- map["currencyCode"]
        centAmount         <- map["centAmount"]
    }

}

// MARK: - CustomStringConvertible

extension Money: CustomStringConvertible {
    /// The textual representation used when written to an output stream, with locale based format
    var description: String {
        if let centAmount = centAmount, currencyCode = currencyCode,
        currencySymbol = NSLocale(localeIdentifier: currencyCode).displayNameForKey(NSLocaleCurrencySymbol, value: currencyCode) {
            let currencyFormatter = NSNumberFormatter()
            currencyFormatter.numberStyle = .CurrencyStyle
            currencyFormatter.currencySymbol = currencySymbol
            currencyFormatter.locale = NSLocale.currentLocale()
            return currencyFormatter.stringFromNumber(centAmount / 100) ?? ""
        }
        return ""
    }
}