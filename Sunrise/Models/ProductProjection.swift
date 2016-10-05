//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ObjectMapper
private func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

private func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


struct ProductProjection: Mappable {

    // MARK: - Properties

    var id: String?
    var name: [String: String]?
    var productTypeId: String?
    var productType: ProductType?
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
        if let prices = masterVariant?.prices, prices.count > 0 {
            return masterVariant
        } else {
            return variants?.filter({ $0.prices?.count > 0 }).first
        }
    }

    init?(map: Map) {}

    // MARK: - Mappable

    mutating func mapping(map: Map) {
        id                 <- map["id"]
        name               <- map["name"]
        productTypeId      <- map["productType.id"]
        productType        <- map["productType.obj"]
        masterVariant      <- map["masterVariant"]
        variants           <- map["variants"]
    }

}
