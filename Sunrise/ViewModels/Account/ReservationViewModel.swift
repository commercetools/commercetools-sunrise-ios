//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import MapKit
import ReactiveSwift
import Result
import CoreLocation
import Commercetools

#if os(iOS)
class ReservationViewModel {

    // Inputs
    let getDirectionObserver: Observer<Void, NoError>

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
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(order: Order) {
        self.order = order

        isLoading = MutableProperty(true)
        storeLocation = MutableProperty(nil)

        let (getDirectionSignal, getDirectionObserver) = Signal<Void, NoError>.pipe()
        self.getDirectionObserver = getDirectionObserver

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

        storeName = order.lineItems?.first?.distributionChannel?.obj?.name?.localizedString
        streetAndNumberInfo = order.lineItems?.first?.distributionChannel?.obj?.streetAndNumberInfo
        zipAndCityInfo = order.lineItems?.first?.distributionChannel?.obj?.zipAndCityInfo
        openLine1Info = order.lineItems?.first?.distributionChannel?.obj?.openingTimes

        disposables += getDirectionSignal.observeValues { [weak self] in
            if let location = self?.storeLocation.value {
                let destination = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                destination.name = self?.storeName
                MKMapItem.openMaps(with: [destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            }
        }

        geocodeStoreAddress()
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Store address geocoding

    private func geocodeStoreAddress() {
        if let channel = order.lineItems?.first?.distributionChannel?.obj, let zip = channel.address?.postalCode,
                let city = channel.address?.city, let street = channel.address?.streetName, let number = channel.address?.streetNumber,
                let country = channel.address?.country {
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
#endif

struct Notification {
    
    struct Category {
        static let reservationConfirmation = "reservation_confirmation"
    }
    
    struct Action {
        static let view = "viewAction"
        static let getDirections = "getDirectionsAction"
    }
}
