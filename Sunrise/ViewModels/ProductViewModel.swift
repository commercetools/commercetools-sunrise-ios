//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveCocoa
import ObjectMapper

class ProductViewModel: BaseViewModel {

    // Inputs
    let size = MutableProperty("")

    // Outputs
    let name: String
    let sizes: [String]
    let sku = MutableProperty("")
    let price = MutableProperty("")
    let oldPrice = MutableProperty("")
    let imageUrl = MutableProperty("")
    let quantities = (1...9).map { String($0) }
    let isLoading = MutableProperty(false)

    // Dialogue texts
    let addToCartSuccessTitle = NSLocalizedString("Product added to cart", comment: "Product added to cart")
    let addToCartSuccessMessage = NSLocalizedString("You have successfully added product to your cart. Would you like to continue looking for more, or go to cart overview?", comment: "Product added to cart message")
    let continueTitle = NSLocalizedString("Continue", comment: "Continue")
    let cartOverviewTitle = NSLocalizedString("Cart overview", comment: "Cart overview")
    let addToCartFailedTitle = NSLocalizedString("Couldn't add product to cart", comment: "Adding product to cart failed")

    // Actions
    lazy var addToCartAction: Action<String, Void, NSError> = { [unowned self] in
        return Action(enabledIf: ConstantProperty(true), { quantity in
            self.isLoading.value = true
            return self.addLineItem(quantity)
        })
    }()

    private let product: ProductProjection

    private var currencyCodeForCurrentLocale: String {
        let currencyFormatter = NSNumberFormatter()
        currencyFormatter.numberStyle = .CurrencyStyle
        currencyFormatter.locale = NSLocale.currentLocale()

        return currencyFormatter.currencyCode
    }

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

        super.init()

        let allVariants = product.allVariants

        if let matchingVariant = allVariants.filter({ $0.isMatchingVariant ?? false }).first,
                matchingSize = matchingVariant.attributes?.filter({ $0.name == "size" }).first?.value as? String {
            size.value = matchingSize
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

    private func currentVariantId() -> Int? {
        return product.allVariants.filter({ $0.sku == sku.value }).first?.id
    }

    // MARK: - Cart interaction

    private func addLineItem(quantity: String = "1") -> SignalProducer<Void, NSError> {
        return SignalProducer { observer, disposable in

            var lineItemDraft: [String: AnyObject] = ["action": "addLineItem", "productId": self.product.id ?? "", "variantId": self.currentVariantId() ?? 1, "quantity": Int(quantity) ?? 1]

            // Get the cart with state Active which has the most recent lastModifiedAt.
            Commercetools.Cart.query(predicates: ["cartState=\"Active\""], sort: ["lastModifiedAt desc"], limit: 1, result: { result in
                if let results = result.response?["results"] as? [[String: AnyObject]],
                carts = Mapper<Cart>().mapArray(results), cart = carts.first, id = cart.id,
                        version = cart.version where result.isSuccess {
                    // In case we already have an active cart, just add selected product
                    lineItemDraft["action"] = "addLineItem"
                    Commercetools.Cart.update(id, version: version, actions: [lineItemDraft], result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let errors = result.errors where result.isFailure {
                            super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                        }
                        self.isLoading.value = false
                    })

                } else if result.isFailure {
                    // If there is no active cart, create one, with the selected product
                    Commercetools.Cart.create(["currency": self.currencyCodeForCurrentLocale, "lineItems": [lineItemDraft]], result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let errors = result.errors where result.isFailure {
                            super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))
                        }
                        self.isLoading.value = false
                    })
                }
            })
        }
    }

}