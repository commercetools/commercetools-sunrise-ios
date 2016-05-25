//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa

class ProductViewModel {

    // Inputs
    let size = MutableProperty("")

    // Outputs
    let name: String
    let sizes: [String]
    let sku = MutableProperty("")
    let price = MutableProperty("")
    let oldPrice = MutableProperty("")
    let imageUrl = MutableProperty("")

    private let product: ProductProjection

    // MARK: Lifecycle

    init(product: ProductProjection) {
        self.product = product

        name = product.name?.localizedString?.uppercaseString ?? ""

        var sizes = [String]()
        // We want to show sizes only for those variants that have prices available
        if let masterVariant = product.masterVariant, prices = masterVariant.prices,
                defaultSize = masterVariant.attributes?.filter({ $0.name == "size" }).first?.value as? String where
                prices.count > 0 {
            sizes.append(defaultSize)
        }
        product.variants?.filter({ $0.prices?.count > 0 }).forEach { variant in
            if let size = variant.attributes?.filter({ $0.name == "size" }).first?.value as? String {
                sizes.append(size)
            }
        }

        self.sizes = sizes
        size.value = sizes.first ?? "N/A"

        let allVariants = product.allVariants

        sku <~ size.producer.map { size in
            return allVariants.filter({ $0.attributes?.filter({ $0.name == "size" }).first?.value as? String == size }).first?.sku ?? ""
        }

        imageUrl <~ size.producer.map { size in
            return allVariants.filter({ $0.attributes?.filter({ $0.name == "size" }).first?.value as? String == size }).first?.images?.first?.url ?? ""
        }

        price <~ size.producer.map { [weak self] size in
            guard let price = self?.priceForSize(size, variants: allVariants), value = price.value else { return "" }

            if let discounted = price.discounted?.value {
                return "\(discounted)"
            } else {
                return "\(value)"
            }
        }

        oldPrice <~ size.producer.map { [weak self] size in
            guard let price = self?.priceForSize(size, variants: allVariants), value = price.value,
                    _ = price.discounted?.value else { return "" }

            return "\(value)"
        }
    }

    // MARK: Internal Helpers

    private func priceForSize(size: String, variants: [ProductVariant]) -> Price? {
        return variants.filter({ $0.attributes?.filter({ $0.name == "size" }).first?.value as? String == size }).first?.independentPrice
    }

}