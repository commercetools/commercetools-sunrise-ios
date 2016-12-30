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

//    func mainVariantWithPrice(for store: Channel? = nil) -> ProductVariant? {
//        if let channelId = store?.id {
//            if let prices = masterVariant?.prices, prices.count > 0 {
//                return masterVariant
//            } else {
//                return variants?.filter({ ($0.prices?.count ?? 0) > 0 }).first
//            }
//        }
//        if let prices = masterVariant?.prices, prices.count > 0 {
//            return masterVariant
//        } else {
//            return variants?.filter({ ($0.prices?.count ?? 0) > 0 }).first
//        }
//    }
}
