//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

// MARK: - CustomStringConvertible

extension BaseMoney {
    /// The textual representation used when written to an output stream, with locale based format
    public var description: String {
        if let currencySymbol = (Locale(identifier: currencyCode) as NSLocale).displayName(forKey: NSLocale.Key.currencySymbol, value: currencyCode) {
            let currencyFormatter = NumberFormatter()
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencySymbol = currencySymbol
            currencyFormatter.locale = Locale(identifier: currencyCode)
            return currencyFormatter.string(from: NSNumber(value: Double(centAmount) / 100)) ?? ""
        }
        return ""
    }
}
