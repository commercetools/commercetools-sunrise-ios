//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import ReactiveSwift

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

            let selectedChannelReference = Reference<Channel>(id: store.id, typeId: "channel")
            let lineItemDraft = LineItemDraft(productVariantSelection: .sku(sku: sku), supplyChannel: selectedChannelReference, distributionChannel: selectedChannelReference)
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
