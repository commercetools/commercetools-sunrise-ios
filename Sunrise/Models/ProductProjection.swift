//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper

struct ProductProjection: Mappable {

    // MARK: - Properties

    var id: String?
    var name: [String: String]?
    var masterVariant: ProductVariant?
    var variants: [ProductVariant]?
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
        if let prices = masterVariant?.prices where prices.count > 0 {
            return masterVariant
        } else {
            return variants?.filter({ $0.prices?.count > 0 }).first
        }
    }

    init?(_ map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id                 <- map["id"]
        name               <- map["name"]
        masterVariant      <- map["masterVariant"]
        variants           <- map["variants"]
    }

}