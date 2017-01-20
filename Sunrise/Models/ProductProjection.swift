//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductProjection {

    /// The `masterVariant` if it has price, or  the first from `variants` with price.
    var mainVariantWithPrice: ProductVariant? {
        if let prices = masterVariant?.prices, prices.count > 0 {
            return masterVariant
        } else {
            return variants?.filter({ ($0.prices?.count ?? 0) > 0 }).first
        }
    }

    /**
        Returns `masterVariant` if it contains price for the specified channel, or the first from `variants` with price
        that fulfils the same condition.

        - parameter channel:            An optional `Channel` instance, used to filter `prices` by.
        - returns:                      An optional `ProductVariant` instance.
    */
    func mainVariantWithPrice(for channel: Channel? = nil) -> ProductVariant? {
        if let channelId = channel?.id {
            if let prices = masterVariant?.prices?.filter({ $0.channel?.id == channelId }), prices.count > 0 {
                return masterVariant
            } else {
                return variants?.filter({ ($0.prices?.filter({ $0.channel?.id == channelId }).count ?? 0) > 0 }).first
            }
        } else {
            return mainVariantWithPrice
        }
    }

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