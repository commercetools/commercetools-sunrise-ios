//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import Foundation
import CoreLocation
import Commercetools

/// Reduced models used for responses for GraphQL queries used by the watch app

struct Me<T: Codable>: Codable {
    let me: T
}

struct OrdersResponse: Codable {
    let orders: QueryResponse<ReducedOrder>
}

struct OrderResponse<T: Codable>: Codable {
    let order: T
}

struct ProductsResponse: Codable {
    let products: QueryResponse<ReducedProduct>
}

struct ProductResponse: Codable {
    let product: ReducedProduct
}

struct ShoppingListsResponse: Codable {
    let shoppingLists: QueryResponse<ReducedShoppingList>
}

struct CreateShoppingListResponse: Codable {
    let createMyShoppingList: ReducedShoppingList
}

struct UpdateShoppingListResponse: Codable {
    let updateMyShoppingList: ReducedShoppingList
}

struct ReducedReservation: Codable {
    let lineItems: [LineItem]
    let totalPrice: Money

    struct LineItem: Codable {
        let distributionChannel: ReducedChannel?
        let variant: ReducedVariant
        let nameAllLocales: [LocalizedString]?
        var name: Commercetools.LocalizedString {
            var name = [String: String]()
            nameAllLocales?.forEach {
                name[$0.locale] = $0.value
            }
            return name
        }

        struct ReducedVariant: Codable {
            let images: [ReducedImage]?
        }

        struct LocalizedString: Codable {
            let locale: String
            let value: String
        }

        struct ReducedImage: Codable {
            let url: String
        }

        struct ReducedChannel: Codable {
            let nameAllLocales: [LocalizedString]?
            var name: Commercetools.LocalizedString {
                var name = [String: String]()
                nameAllLocales?.forEach {
                    name[$0.locale] = $0.value
                }
                return name
            }
            let address: Address?
            let geoLocation: Point?
            let custom: Custom?
        }

        struct Custom: Codable {
            let customFieldsRaw: [RawCustomField]?
        }

        struct RawCustomField: Codable {
            let name: String
            let value: JsonValue
        }

        struct Point: Codable {
            let coordinates: [Double]
            let type: String
        }
    }
}

extension ReducedReservation.LineItem.ReducedChannel {

    // MARK: - Physical store properties

    var streetAndNumberInfo: String {
        if let street = address?.streetName, let number = address?.streetNumber {
            return "\(street) \(number)"
        }
        return "-"
    }
    var zipAndCityInfo: String {
        if let zip = address?.postalCode, let city = address?.city {
            return "\(zip), \(city)"
        }
        return "-"
    }
    var openingTimes: String {
        if let openingTimes = custom?.customFieldsRaw?.first(where: { $0.name == "openingTimes" })?.value.dictionary {
            return localizedString(from: openingTimes) ?? "-"
        }
        return "-"
    }
    var location: CLLocation? {
        if let geoLocation = geoLocation, geoLocation.coordinates.count == 2, geoLocation.type == "Point" {
            return CLLocation(latitude: geoLocation.coordinates[1], longitude: geoLocation.coordinates[0])
        }
        return nil
    }
    func distance(from userLocation: CLLocation) -> Double? {
        if let channelLocation = location {
            return userLocation.distance(from: channelLocation)
        }
        return nil
    }
}

extension ReducedReservation {
    static let reducedReservationQuery = """
                                        totalPrice {
                                          type
                                          centAmount
                                          currencyCode
                                        }
                                        lineItems {
                                          distributionChannel {
                                            nameAllLocales {
                                              locale
                                              value
                                            }
                                            address {
                                              streetName
                                              streetNumber
                                              postalCode
                                              city
                                              country
                                            }
                                            geoLocation {
                                              ... on Point {
                                                coordinates
                                                type
                                              }
                                            }
                                            custom {
                                              customFieldsRaw {
                                                name
                                                value
                                              }
                                            }
                                          }
                                          variant {
                                            images {
                                              url
                                            }
                                          }
                                          nameAllLocales {
                                            locale
                                            value
                                          }
                                        }
                                        """
}

struct ReducedOrder: Codable {
    let id: String
    let orderNumber: String?
    let orderState: OrderState
    let shipmentState: ShipmentState?
    let lineItems: [LineItem]
    let shippingAddress: Address?
    let totalPrice: Money
    let taxedPrice: TaxedPrice?

    struct LineItem: Codable {
        let quantity: Int
        let nameAllLocales: [LocalizedString]
        var name: Commercetools.LocalizedString {
            var name = [String: String]()
            nameAllLocales.forEach {
                name[$0.locale] = $0.value
            }
            return name
        }

        struct LocalizedString: Codable {
            let locale: String
            let value: String
        }
    }

    struct TaxedPrice: Codable {
        let totalGross: Money
    }
}

extension ReducedOrder {
    static let reducedOrderQuery = """
                                    totalPrice {
                                      type
                                      currencyCode
                                      centAmount
                                      fractionDigits
                                    }
                                    id
                                    orderState
                                    shipmentState
                                    orderNumber
                                    lineItems {
                                      nameAllLocales {
                                        locale
                                        value
                                      }
                                      quantity
                                    }
                                    shippingAddress {
                                      streetName
                                      additionalStreetInfo
                                      city
                                      region
                                      state
                                      postalCode
                                      country
                                    }
                                    taxedPrice {
                                      totalGross {
                                        type
                                        currencyCode
                                        centAmount
                                        fractionDigits
                                      }
                                    }
                                    """
}

struct ReducedProduct: Codable {
    let id: String
    let masterData: MasterData
    var name: Commercetools.LocalizedString {
        return masterData.current.name
    }
    var allVariants: [ReducedVariant] {
        return masterData.current.allVariants
    }

    struct MasterData: Codable {
        let current: ProductInfo
        let published: Bool
    }

    struct ProductInfo: Codable {
        let allVariants: [ReducedVariant]

        let nameAllLocales: [LocalizedString]
        var name: Commercetools.LocalizedString {
            var name = [String: String]()
            nameAllLocales.forEach {
                name[$0.locale] = $0.value
            }
            return name
        }

        struct LocalizedString: Codable {
            let locale: String
            let value: String
        }
    }

    struct ReducedVariant: Codable {
        let id: Int
        let sku: String?
        let images: [ReducedImage]?
        let prices: [ReducedPrice]?

        init(variant: ProductVariant) {
            id = variant.id
            sku = variant.sku
            images = variant.images?.map { ReducedImage(image: $0) }
            prices = variant.prices?.map { ReducedPrice(price: $0) }
        }
    }

    struct ReducedImage: Codable {
        let url: String

        init(image: Image) {
            url = image.url
        }
    }

    struct ReducedPrice: Codable {
        let value: Money
        let country: String?
        let customerGroup: ReducedReference?
        let channel: ReducedReference?
        let validFrom: Date?
        let validUntil: Date?
        let discounted: ReducedDiscountedPrice?

        init(price: Price) {
            value = Money(currencyCode: price.value.currencyCode, centAmount: price.value.centAmount)
            country = price.country
            customerGroup = price.customerGroup != nil ? ReducedReference(id: price.customerGroup!.id) : nil
            channel = price.channel != nil ? ReducedReference(id: price.channel!.id) : nil
            validFrom = price.validFrom
            validUntil = price.validUntil
            discounted = price.discounted != nil ? ReducedDiscountedPrice(discountedPrice: price.discounted!) : nil
        }
    }

    struct ReducedReference: Codable {
        let id: String
    }

    struct ReducedDiscountedPrice: Codable {
        let value: Money

        init(discountedPrice: DiscountedPrice) {
            value = discountedPrice.value
        }
    }

    init(productProjection: ProductProjection) {
        id = productProjection.id
        let nameAllLocales = productProjection.name.keys.map({ ReducedProduct.ProductInfo.LocalizedString(locale: $0, value: productProjection.name[$0]!) })
        let allVariants = productProjection.allVariants.map({ ReducedVariant(variant: $0) })
        let current = ReducedProduct.ProductInfo(allVariants: allVariants, nameAllLocales: nameAllLocales)
        masterData = ReducedProduct.MasterData(current: current, published: true)
    }
}

extension ReducedProduct {
    static let reducedProductQuery = """
                                    id
                                    masterData {
                                      published
                                      current {
                                        nameAllLocales {
                                          locale
                                          value
                                        }
                                        allVariants {
                                          ...Variant
                                        }
                                      }
                                    }
                                    """

    static let moneyFragment = """
                                fragment Money on BaseMoney {
                                  currencyCode
                                  centAmount
                                }
                                """
    static let variantFragment = """
                                fragment Variant on ProductVariant {
                                  id
                                  sku
                                  images {
                                    url
                                  }
                                  prices {
                                    validFrom
                                    validUntil
                                    country
                                    customerGroup {
                                      id
                                    }
                                    value {
                                      ...Money
                                    }
                                    discounted {
                                      value {
                                        ...Money
                                      }
                                    }
                                  }
                                }
                                """
}

extension ReducedProduct {

    func displayVariant(country: String? = Customer.currentCountry, currency: String? = Customer.currentCurrency, customerGroup: Reference<CustomerGroup>? = Customer.customerGroup) -> ReducedVariant? {
        return displayVariants(country: country, currency: currency, customerGroup: customerGroup).first
    }

    func displayVariants(country: String? = Customer.currentCountry, currency: String? = Customer.currentCurrency, customerGroup: Reference<CustomerGroup>? = Customer.customerGroup) -> [ReducedVariant] {
        var displayVariants = [ReducedVariant]()
        let allVariants = masterData.current.allVariants
        let now = Date()
        displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil
            && $0.validUntil! > now && $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        if customerGroup != nil {
            displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil
                && $0.validUntil! > now && $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 })
            displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.country == country && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        }
        displayVariants += allVariants.filter({ !displayVariants.contains($0) && $0.prices?.filter({ $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).count ?? 0 > 0 })
        if let mainVariantWithPrice = mainVariantWithPrice, displayVariants.isEmpty {
            displayVariants.append(mainVariantWithPrice)
        }
        return displayVariants
    }

    var mainVariantWithPrice: ReducedProduct.ReducedVariant? {
        return masterData.current.allVariants.filter({ ($0.prices?.count ?? 0) > 0 }).first
    }
}

extension ReducedProduct.ReducedVariant: Equatable {
    public static func ==(lhs: ReducedProduct.ReducedVariant, rhs: ReducedProduct.ReducedVariant) -> Bool {
        return lhs.id == rhs.id
    }
}

extension ReducedProduct.ReducedVariant {

    /// The price without channel, customerGroup, country and validUntil/validFrom
    private var independentPrice: ReducedProduct.ReducedPrice? {
        return prices?.filter({ price in
            if price.channel == nil && price.customerGroup == nil && price.country == nil
                && price.validFrom == nil && price.validUntil == nil {
                return true
            }
            return false
        }).first
    }

    func price(country: String? = Customer.currentCountry, currency: String? = Customer.currentCurrency, customerGroup: Reference<CustomerGroup>? = Customer.customerGroup) -> ReducedProduct.ReducedPrice? {
        let now = Date()
        var price = prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
            && $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).first
        if price == nil, customerGroup != nil {
            price = prices?.filter({ $0.validFrom != nil && $0.validFrom! < now && $0.validUntil != nil && $0.validUntil! > now
                && $0.country == country && $0.value.currencyCode == currency }).first
        }
        if price == nil {
            price = prices?.filter({ $0.country == country && $0.customerGroup?.id == customerGroup?.id && $0.value.currencyCode == currency }).first
        }
        if price == nil, customerGroup != nil {
            price = prices?.filter({ $0.country == country && $0.value.currencyCode == currency }).first
        }
        if price == nil {
            price = independentPrice
        }
        return price
    }
}

struct ReducedShoppingList: Codable {
    let id: String
    let version: UInt
    let lineItems: [ReducedLineItem]

    struct ReducedLineItem: Codable {
        let id: String
        let productId: String
        let variantId: Int?
        let variant: ReducedProduct.ReducedVariant?
        let nameAllLocales: [LocalizedString]?
        var name: Commercetools.LocalizedString {
            var name = [String: String]()
            nameAllLocales?.forEach {
                name[$0.locale] = $0.value
            }
            return name
        }

        struct LocalizedString: Codable {
            let locale: String
            let value: String
        }
    }
}

extension ReducedShoppingList {
    static func reducedShoppingListQuery(includeExpansion: Bool = false) -> String {
        return """
                id
                version
                lineItems {
                  id
                  productId
                  variantId
                  \(includeExpansion ? "variant { ...Variant }" : "")
                  nameAllLocales {
                    locale
                    value
                  }
                }
                """
    }

    static func createShoppingListMutation(name: String) -> String {
        return """
                mutation CreateMyShoppingList {
                  createMyShoppingList(draft: {
                    name: [{
                      locale: "en"
                      value: "\(name)"
                    }]
                  }) {
                    \(reducedShoppingListQuery(includeExpansion: false))
                  }
                }
                """
    }

    static func updateLineItemsMutation(id: String, version: UInt, add: (productId: String, variantId: Int?)?, remove lineItemId: String?) -> String {
        return """
                mutation UpdateMyShoppingList {
                  updateMyShoppingList(
                    id: "\(id)"
                    version: \(version)
                    actions: [
                      \(add?.productId != nil ? "{ addLineItem: { productId: \"\(add!.productId)\" \(add!.variantId != nil ? "variantId: \(add!.variantId!)" : "") } }" : "")
                      \(lineItemId != nil ? "{ removeLineItem: { lineItemId: \"\(lineItemId!)\" } }" : "")
                    ]
                  ) {
                    \(reducedShoppingListQuery(includeExpansion: true))
                  }
                }
                """
    }
}
