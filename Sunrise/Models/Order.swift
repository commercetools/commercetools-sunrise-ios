//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift
import Intents

extension Order {
    var isReservation: Bool {
        return custom?.dictionary?["fields"]?.dictionary?["isReservation"]?.bool == true
    }

    #if os(iOS)
    static func reserveProduct(sku: String, in store: Channel) -> SignalProducer<Void, CTError> {
        return SignalProducer { observer, disposable in
            guard let shippingAddress = store.address else {
                observer.send(error: CTError.generalError(reason: nil))
                return
            }

            let selectedChannel = ResourceIdentifier(id: store.id, typeId: .channel)
            let lineItemDraft = LineItemDraft(productVariantSelection: .sku(sku: sku), supplyChannel: selectedChannel, distributionChannel: selectedChannel)
            let customType = JsonValue.dictionary(value: ["type": .dictionary(value: ["key": .string(value: "reservationOrder")]),
                                                           "fields": .dictionary(value: ["isReservation": .bool(value: true)])])

            Customer.profile { result in
                if let profile = result.model, result.isSuccess {

                    let billingAddress = profile.addresses.filter({ $0.id == profile.defaultBillingAddressId }).first ?? Address(firstName: profile.firstName, lastName: profile.lastName, country: store.address?.country ?? "")

                    let cartDraft = CartDraft(currency: Customer.currentCurrency ?? Locale.currencyCodeForCurrentLocale, customerEmail: profile.email, lineItems: [lineItemDraft], shippingAddress: shippingAddress, billingAddress: billingAddress, custom: customType)
                    Commercetools.Cart.create(cartDraft, result: { result in

                        if let cart = result.model, result.isSuccess {
                            let orderDraft = OrderDraft(id: cart.id, version: cart.version)
                            Order.create(orderDraft, expansion: nil, result: { result in
                                if result.isSuccess {
                                    observer.send(value: ())
                                    observer.sendCompleted()
                                } else if let error = result.errors?.first as? CTError, result.isFailure {
                                    observer.send(error: error)
                                }
                            })

                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                    })
                } else if let error = result.errors?.first as? CTError, result.isFailure {
                    observer.send(error: error)
                }
            }
        }
    }
    #endif
}

@available(iOS 12.0, *)
@available(watchOSApplicationExtension 5.0, *)
extension Order {
    var reorderIntent: OrderProductIntent {
        let intent = OrderProductIntent()
        intent.previousOrderId = id
        intent.firstLineItemName = lineItems.first?.name.localizedString
        intent.otherLineItemsCount = lineItems.count > 1 ? (lineItems.count - 1) as NSNumber : nil
        var suggestedInvocationPhrase = NSString.deferredLocalizedIntentsString(with: "Order %@", intent.firstLineItemName ?? "") as String
        if let otherLineItemsCount = intent.otherLineItemsCount {
            suggestedInvocationPhrase.append(NSString.deferredLocalizedIntentsString(with: " and %@ more", otherLineItemsCount) as String)
        }
        intent.suggestedInvocationPhrase = suggestedInvocationPhrase
        return intent
    }

    var reserveIntent: ReserveProductIntent {
        let intent = ReserveProductIntent()
        let reservedProduct = lineItems.first
        intent.previousReservationId = id
        intent.lineItemName = reservedProduct?.name.localizedString
        intent.storeName = reservedProduct?.distributionChannel?.obj?.name?.localizedString
        intent.suggestedInvocationPhrase = NSString.deferredLocalizedIntentsString(with: "Reserve %@ for pickup at %@", intent.lineItemName ?? "", intent.storeName ?? "") as String
        return intent
    }
}

extension Order {
    func createReorderCart(completion: @escaping (Cart?) -> Void) {
        let lineItemsDraft = lineItems.map({ LineItemDraft(productVariantSelection: .productVariant(productId: $0.productId, variantId: $0.variant.id), quantity: UInt($0.quantity)) })
        let cartDraft = CartDraft(currency: totalPrice.currencyCode, customerEmail: customerEmail, lineItems: lineItemsDraft, shippingAddress: shippingAddress, billingAddress: billingAddress, shippingMethod: ResourceIdentifier(id: shippingInfo?.shippingMethod?.id, typeId: .shippingMethod))
        Cart.create(cartDraft) { result in
            completion(result.model)
        }
    }
}

extension Order {
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
