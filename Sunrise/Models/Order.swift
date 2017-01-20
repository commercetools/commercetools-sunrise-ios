//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift

extension Order {
    var isReservation: Bool {
        return ((custom?["fields"] as? [String: Any])?["isReservation"] as? Bool) == true
    }

    #if os(iOS)
    static func reserve(product: ProductProjection?, variant: ProductVariant?, in store: Channel) -> SignalProducer<Void, CTError> {
        return SignalProducer { observer, disposable in
            guard let channelId = store.id, let productId = product?.id, let variantId = variant?.id,
                  let shippingAddress = store.address else {
                observer.send(error: CTError.generalError(reason: nil))
                return
            }

            var selectedChannelReference = Reference<Channel>()
            selectedChannelReference.typeId = "channel"
            selectedChannelReference.id = channelId
            var lineItemDraft = LineItemDraft()
            lineItemDraft.productId = productId
            lineItemDraft.variantId = variantId
            lineItemDraft.supplyChannel = selectedChannelReference
            lineItemDraft.distributionChannel = selectedChannelReference
            let customType = ["type": ["key": "reservationOrder"],
                              "fields": ["isReservation": true]]

            Customer.profile { result in
                if let profile = result.model, result.isSuccess {

                    var billingAddress = profile.reservationAddress

                    // In case the customer doesn't even have a country set in the address,
                    // it's being set to match the channel country.
                    if billingAddress.country == nil {
                        billingAddress.country = store.address?.country
                    }

                    var cartDraft = CartDraft()
                    cartDraft.currency = BaseViewModel.currencyCodeForCurrentLocale
                    cartDraft.shippingAddress = shippingAddress
                    cartDraft.billingAddress = billingAddress
                    cartDraft.lineItems = [lineItemDraft]
                    cartDraft.custom = customType
                    Commercetools.Cart.create(cartDraft, result: { result in

                        if let cart = result.model, let id = cart.id, let version = cart.version, result.isSuccess {
                            var orderDraft = OrderDraft()
                            orderDraft.id = id
                            orderDraft.version = version
                            Order.create(orderDraft, expansion: nil, result: { result in
                                if result.isSuccess {
                                    observer.send(value: ())
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