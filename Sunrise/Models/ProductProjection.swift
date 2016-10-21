//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductProjection {

    /// The union of `masterVariant` and other`variants`.
    var allVariants: [ProductVariant] {
        var allVariants = [ProductVariant]()
        if let masterVariant = masterVariant {
            allVariants.append(masterVariant)
        }
        if let otherVariants = variants {
            allVariants += otherVariants
        }
        return allVariants
    }
    /// The `masterVariant` if it has price, or first from `variants` with price.
    var mainVariantWithPrice: ProductVariant? {
        if let prices = masterVariant?.prices, prices.count > 0 {
            return masterVariant
        } else {
            return variants?.filter({ ($0.prices?.count ?? 0) > 0 }).first
        }
    }
}
