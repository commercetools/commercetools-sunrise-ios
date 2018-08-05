//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveSwift
import Result
import CoreLocation
import MapKit

class ReservationConfirmationViewModel {

    // Inputs
    var getDirectionsAction: Action<Void, Void, NoError>!

    // Outputs
    let storeName: MutableProperty<String?> = MutableProperty(nil)
    let openingTimes: MutableProperty<String?> = MutableProperty(nil)
    let storeAddress: MutableProperty<String?> = MutableProperty(nil)

    private let store: Channel
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(store: Channel) {
        self.store = store

        storeName.value = store.name?.localizedString
        openingTimes.value = store.openingTimes
        storeAddress.value = "\(store.streetAndNumberInfo)\n\(store.zipAndCityInfo)"

        getDirectionsAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            if let location = store.location {
                self.getDirections(for: location, name: self.storeName.value)
            }
            return SignalProducer.empty
        }
    }

    deinit {
        disposables.dispose()
    }

    private func getDirections(for location: CLLocation, name: String? = nil) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        destination.name = name
        MKMapItem.openMaps(with: [destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
