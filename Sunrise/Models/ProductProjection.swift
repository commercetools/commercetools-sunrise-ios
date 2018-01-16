//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductProjection {

    func displayVariant(country: String? = nil, currency: String? = nil, customerGroup: Reference<CustomerGroup>? = nil) -> ProductVariant? {
        var displayVariant = allVariants.filter({ $0.isMatchingVariant == true }).first
        let now = Date()
        if displayVariant == nil {
            displayVariant = allVariants.filter({ $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                    && $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 }).first
        }
        if displayVariant == nil, customerGroup != nil {
            displayVariant = allVariants.filter({ $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                    && $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 }).first
        }
        if displayVariant == nil {
            displayVariant = allVariants.filter({ $0.prices?.filter({ $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 }).first
        }
        if displayVariant == nil, customerGroup != nil {
            displayVariant = allVariants.filter({ $0.prices?.filter({ $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 }).first
        }
        if displayVariant == nil {
            displayVariant = mainVariantWithPrice
        }
        return displayVariant
    }

    /// The `masterVariant` if it has price, or  the first from `variants` with price.
    var mainVariantWithPrice: ProductVariant? {
        if let prices = masterVariant.prices, prices.count > 0 {
            return masterVariant
        } else {
            return variants.filter({ ($0.prices?.count ?? 0) > 0 }).first
        }
    }
}