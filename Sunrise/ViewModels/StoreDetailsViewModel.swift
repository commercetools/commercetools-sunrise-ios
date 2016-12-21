//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import MapKit
import ReactiveSwift
import Result
import CoreLocation
import Commercetools

class StoreDetailsViewModel {

    // Outputs
    var storeLocation: CLLocation? {
        return store.location
    }
    var storeImageUrl: String {
        return store.imageUrl ?? ""
    }
    var storeName: String? {
        return store.name?.localizedString
    }
    var streetAndNumberInfo: String? {
        return store.streetAndNumberInfo
    }
    var zipAndCityInfo: String? {
        return store.zipAndCityInfo
    }
    var openLine1Info: String? {
        return store.openingTimes
    }
    var myStore: MutableProperty<Channel?>? {
        return AppRouting.accountViewController?.viewModel?.myStore
    }
    let successTitle = NSLocalizedString("My Store Saved", comment: "My store saved")
    let successMessage: String

    // Actions
    lazy var getDirectionsAction: Action<Void, Void, NoError> = {
        return Action(enabledIf: Property(value: true), { _ in
            return SignalProducer { [weak self] observer, disposable in
                if let location = self?.storeLocation {
                    self?.getDirections(for: location, name: self?.storeName)
                }
                observer.sendCompleted()
            }
        })
    }()
    lazy var saveMyStoreAction: Action<Void, Void, NoError> = {
        return Action(enabledIf: Property(value: true), { _ in
            return SignalProducer { [weak self] observer, disposable in
                AppRouting.accountViewController?.viewModel?.myStore.value = self?.store
                if let myStoreId = self?.store.id {
                    UserDefaults.standard.set(myStoreId, forKey: kMyStoreId)
                } else {
                    UserDefaults.standard.removeObject(forKey: kMyStoreId)
                }
                observer.sendCompleted()
            }
        })
    }()

    let store: Channel

    // MARK: - Lifecycle

    init(store: Channel) {
        self.store = store
        successMessage = NSLocalizedString((store.name?.localizedString ?? "") + " has been saved as your preferred store.", comment: "My store saved details")
    }

    private func getDirections(for location: CLLocation, name: String? = nil) {
        let destination = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        destination.name = name
        MKMapItem.openMaps(with: [destination], launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
