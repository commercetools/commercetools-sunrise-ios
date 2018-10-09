//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import MapKit
import CoreLocation
import ReactiveSwift
import Result
import Commercetools

class ReservationDetailsInterfaceModel {

    // Inputs
    let getDirectionObserver: Signal<Void, NoError>.Observer

    // Outputs
    var productName: String {
        return reservation.lineItems.first?.name.localizedString ?? ""
    }
    var productPrice: String? {
        return reservation.totalPrice.description
    }
    var storeName: String? {
        return reservation.lineItems.first?.distributionChannel?.obj?.name?.localizedString
    }
    var storeDistance: String? {
        if let lat = UserDefaults.standard.object(forKey: userLatitudeKey) as? Double,
            let lon = UserDefaults.standard.object(forKey: userLongitudeKey) as? Double,
            let distance = reservation.lineItems.first?.distributionChannel?.obj?.distance(from: CLLocation(latitude: lat, longitude: lon)) {
            if Locale.current.usesMetricSystem {
                return String(format: "%.1f", arguments: [distance / 1000]) + " km away"
            } else {
                return String(format: "%.1f", arguments: [distance / 1609.3]) + " miles away"
            }
        }
        return nil
    }
    var storeLocation: CLLocation? {
        return reservation.lineItems.first?.distributionChannel?.obj?.location
    }
    var productImageUrl: String {
        return reservation.lineItems.first?.variant.images?.first?.url ?? ""
    }
    var streetAndNumberInfo: String? {
        return reservation.lineItems.first?.distributionChannel?.obj?.streetAndNumberInfo
    }
    var zipAndCityInfo: String? {
        return reservation.lineItems.first?.distributionChannel?.obj?.zipAndCityInfo
    }
    var openingTimes: String? {
        return reservation.lineItems.first?.distributionChannel?.obj?.openingTimes
    }

    private let reservation: Order

    // MARK: - Lifecycle

    init(reservation: Order) {
        self.reservation = reservation

        let (getDirectionSignal, getDirectionObserver) = Signal<Void, NoError>.pipe()
        self.getDirectionObserver = getDirectionObserver

        getDirectionSignal.observeValues { [weak self] in
            if let location = self?.storeLocation {
                let destination = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                destination.name = self?.storeName
                MKMapItem.openMaps(with: [destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            }
        }
    }
}
