//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa

class ProductViewModel {

    // Inputs
    let size = MutableProperty("")
//    let size: MutableProperty<String>

    // Outputs
    let name: String
    let sizes: [String]
    let sku = MutableProperty("")
    let price = MutableProperty("")
    let oldPrice = MutableProperty("")
    let imageUrl = MutableProperty("")

    // Actions
//    lazy var addToCartAction: Action<NSIndexPath, Bool, NSError> = { [unowned self] in
//        return Action({ indexPath in
//            let match = self.matchAtIndexPath(indexPath)
//            return self.store.deleteMatch(match)
//        })
//    }()

    private let product: ProductProjection

    // MARK: Lifecycle

    init(product: ProductProjection) {
        self.product = product

        name = product.name?.localizedString?.uppercaseString ?? ""

        var sizes = [String]()
        // We want to show sizes only for those variants that have prices available
        if let masterVariant = product.masterVariant, prices = masterVariant.prices,
                defaultSize = masterVariant.attributes?.filter({ $0.name == "size" }).first?.value as? String where
                prices.count > 0{
            sizes.append(defaultSize)
        }
        product.variants?.filter({ $0.prices?.count > 0 }).forEach { variant in
            if let size = variant.attributes?.filter({ $0.name == "size" }).first?.value as? String {
                sizes.append(size)
            }
        }

        self.sizes = sizes
        size.value = sizes.first ?? "N/A"

        var allVariants = [ProductVariant]()
        if let masterVariant = product.masterVariant {
            allVariants.append(masterVariant)
        }
        if let otherVariants = product.variants {
            allVariants += otherVariants
        }

        sku <~ size.producer.map { size in
            return allVariants.filter({ $0.attributes?.filter({ $0.name == "size" }).first?.value as? String == size }).first?.sku ?? ""
        }

        imageUrl <~ size.producer.map { size in
            return allVariants.filter({ $0.attributes?.filter({ $0.name == "size" }).first?.value as? String == size }).first?.images?.first?.url ?? ""
        }

        price <~ size.producer.map { [weak self] size in
            guard let price = self?.priceForSize(size, variants: allVariants), value = price.value else { return "" }

            if let discounted = price.discounted?.value {
                return self?.formatPriceValue(discounted) ?? ""
            } else {
                return self?.formatPriceValue(value) ?? ""
            }
        }

        oldPrice <~ size.producer.map { [weak self] size in
            guard let price = self?.priceForSize(size, variants: allVariants), value = price.value,
                    _ = price.discounted?.value else { return "" }

            return self?.formatPriceValue(value) ?? ""
        }
    }

    private func priceForSize(size: String, variants: [ProductVariant]) -> Price? {
        return variants.filter({ $0.attributes?.filter({ $0.name == "size" }).first?.value as? String == size }).first?
                        .prices?.filter({ price in
                            // Always pick the price without channel, customerGroup, country and validUntil/validFrom
                            if price.channel == nil && price.customerGroup == nil && price.country == nil
                                    && price.validUntil == nil && price.validUntil == nil {
                                return true
                            }
                            return false
                        }).first
    }

    private func formatPriceValue(value: Money) -> String? {
        if let centAmount = value.centAmount, currencyCode = value.currencyCode,
                currencySymbol = NSLocale(localeIdentifier: currencyCode).displayNameForKey(NSLocaleCurrencySymbol, value: currencyCode) {
            let currencyFormatter = NSNumberFormatter()
            currencyFormatter.numberStyle = .CurrencyStyle
            currencyFormatter.currencySymbol = currencySymbol
            currencyFormatter.locale = NSLocale.currentLocale()
            return currencyFormatter.stringFromNumber(centAmount / 100)
        }
        return nil
    }

}