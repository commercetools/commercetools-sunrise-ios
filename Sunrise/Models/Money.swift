//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Money {
    init(currencyCode: String? = nil, centAmount: Int? = nil) {
        self.currencyCode = currencyCode
        self.centAmount = centAmount
    }
}

// MARK: - CustomStringConvertible

extension Money: CustomStringConvertible {
    /// The textual representation used when written to an output stream, with locale based format
    public var description: String {
        if let centAmount = centAmount, let currencyCode = currencyCode,
           let currencySymbol = (Locale(identifier: currencyCode) as NSLocale).displayName(forKey: NSLocale.Key.currencySymbol, value: currencyCode) {
            let currencyFormatter = NumberFormatter()
            currencyFormatter.numberStyle = .currency
            currencyFormatter.currencySymbol = currencySymbol
            currencyFormatter.locale = Locale.current
            return currencyFormatter.string(from: NSNumber(value: Double(centAmount) / 100)) ?? ""
        }
        return ""
    }
}