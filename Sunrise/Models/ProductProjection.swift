//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductProjection {

    /// The `masterVariant` if it has price, or first from `variants` with price.
    var mainVariantWithPrice: ProductVariant? {
        if let prices = masterVariant?.prices, prices.count > 0 {
            return masterVariant
        } else {
            return variants?.filter({ ($0.prices?.count ?? 0) > 0 }).first
        }
    }

    /// The union of `masterVariant` and other `variants`.
    /**
        Creates and returns an array of `ProductVariant`s containing the union of `masterVariant` and other `variants`.

        - parameter channel:            If specified, returned `ProductVariant` array will contain only those variants
                                        which are on stock for the channel provided.
        - returns:                      An array of `ProductVariant`s.
    */
    func allVariants(for channel: Channel? = nil) -> [ProductVariant] {
        if let channelId = channel?.id {
            return allVariants.filter { variant in
                variant.availability?.channels?[channelId]?.isOnStock == true
            }
        } else {
            return allVariants
        }
    }
}