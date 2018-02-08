//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductProjection {

    func displayVariant(country: String? = AppDelegate.currentCountry, currency: String? = AppDelegate.currentCurrency, customerGroup: Reference<CustomerGroup>? = AppDelegate.customerGroup) -> ProductVariant? {
        return displayVariants(country: country, currency: currency, customerGroup: customerGroup).first
    }

    func displayVariants(country: String? = AppDelegate.currentCountry, currency: String? = AppDelegate.currentCurrency, customerGroup: Reference<CustomerGroup>? = AppDelegate.customerGroup) -> [ProductVariant] {
        var displayVariants = [ProductVariant]()
        let now = Date()
        displayVariants += allVariants.filter({ $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                && $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        if displayVariants.isEmpty, customerGroup != nil {
            displayVariants += allVariants.filter({ $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                    && $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        }
        if displayVariants.isEmpty {
            displayVariants += allVariants.filter({ $0.prices?.filter({ $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        }
        if displayVariants.isEmpty, customerGroup != nil {
            displayVariants += allVariants.filter({ $0.prices?.filter({ $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        }
        if let mainVariantWithPrice = mainVariantWithPrice, displayVariants.isEmpty {
            displayVariants.append(mainVariantWithPrice)
        }
        return displayVariants
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