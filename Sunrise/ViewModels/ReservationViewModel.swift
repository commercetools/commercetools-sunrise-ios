//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class ReservationViewModel {

    // Outputs
    let isLoading: MutableProperty<Bool>
    let storeLocation: MutableProperty<CLLocation?>
    let productName: String?
    let size: String
    let quantity: String?
    let price: String?
    let productImageUrl: String
    let storeName: String?
    let streetAndNumberInfo: String?
    let zipAndCityInfo: String?
    let openLine1Info: String?

    private let order: Order
    private let geocoder = CLGeocoder()

    // MARK: - Lifecycle

    init(order: Order) {
        self.order = order

        isLoading = MutableProperty(true)
        storeLocation = MutableProperty(nil)

        productName = order.lineItems?.first?.name?.localizedString
        productImageUrl = order.lineItems?.first?.variant?.images?.first?.url ?? ""
        size = order.lineItems?.first?.variant?.attributes?.filter({ $0.name == "size" }).first?.value as? String ?? "N/A"
        quantity = String(order.lineItems?.first?.quantity ?? 1)

        if let discounted = order.lineItems?.first?.price?.discounted?.value {
            price = discounted.description
        } else if let price = order.lineItems?.first?.price?.value {
            self.price = price.description
        } else {
            price = nil
        }

        storeName = order.lineItems?.first?.distributionChannel?.name?.localizedString
        streetAndNumberInfo = order.lineItems?.first?.distributionChannel?.streetAndNumberInfo
        zipAndCityInfo = order.lineItems?.first?.distributionChannel?.zipAndCityInfo
        openLine1Info = order.lineItems?.first?.distributionChannel?.openingTimes

        geocodeStoreAddress()
    }

    // MARK: - Store address geocoding

    private func geocodeStoreAddress() {
        if let channel = order.lineItems?.first?.distributionChannel, zip = channel.address?.postalCode,
                city = channel.address?.city, street = channel.address?.streetName, number = channel.address?.streetNumber,
                country = channel.address?.country {
            self.geocoder.geocodeAddressString("\(number) \(street) \(zip) \(city) \(country)", completionHandler: { placemarks, error in
                if let location = placemarks?.first?.location {
                    self.storeLocation.value = location
                }
                self.isLoading.value = false
            })
        } else {
            self.isLoading.value = false
        }
    }

}
