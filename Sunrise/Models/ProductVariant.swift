//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductVariant {

    /// The price without channel, customerGroup, country and validUntil/validFrom
    var independentPrice: Price? {
        return prices?.filter({ price in
            if price.channel == nil && price.customerGroup == nil && price.country == nil
               && price.validFrom == nil && price.validUntil == nil {
                return true
            }
            return false
        }).first
    }

    func price(country: String? = nil, currency: String? = nil, customerGroup: Reference<CustomerGroup>? = nil) -> Price? {
        let now = Date()
        var price = prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                && $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).first
        if price == nil, customerGroup != nil {
            price = prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                    && $0.country == country && $0.value.currencyCode == currency }).first
        }
        if price == nil {
            price = prices?.filter({ $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).first
        }
        if price == nil, customerGroup != nil {
            price = prices?.filter({ $0.country == country && $0.value.currencyCode == currency }).first
        }
        if price == nil {
            price = independentPrice
        }
        return price
    }
}