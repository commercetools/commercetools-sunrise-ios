//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveSwift
import Result
import CoreLocation
import MapKit

class MyStoreViewModel: BaseViewModel {

    // Inputs
    let selectedIndexPathObserver: Observer<IndexPath, NoError>
    let selectedPinCoordinateObserver: Observer<CLLocationCoordinate2D?, NoError>
    let refreshObserver: Observer<Void, NoError>
    let userLocation: MutableProperty<CLLocation?>
    let isActive = MutableProperty(true)

    // Outputs
    let isLoading: MutableProperty<Bool>
    let visibleMapRect: MutableProperty<MKMapRect>
    let storeLocations: MutableProperty<[CLLocation]>
    let presentStoreDetailsSignal: Signal<Void, NoError>
    var myStoreIndexPath: IndexPath? {
        if let myStore = myStore?.value, let row = channels.value.index(of: myStore) {
            return IndexPath(row: row, section: 0)
        }
        return nil
    }
    var storeDetailsViewModel: StoreDetailsViewModel?

    private let channels: MutableProperty<[Channel]>

    // MARK: - Lifecycle

    override init() {
        userLocation = MutableProperty(nil)
        isLoading = MutableProperty(true)
        visibleMapRect = MutableProperty(MKMapRectNull)
        storeLocations = MutableProperty([])
        channels = MutableProperty([])

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedIndexPathObserver = selectedIndexPathObserver

        let (selectedPinCoordinateSignal, selectedPinCoordinateObserver) = Signal<CLLocationCoordinate2D?, NoError>.pipe()
        self.selectedPinCoordinateObserver = selectedPinCoordinateObserver

        let (presentStoreDetailsSignal, presentStoreDetailsObserver) = Signal<Void, NoError>.pipe()
        self.presentStoreDetailsSignal = presentStoreDetailsSignal

        super.init()

        storeLocations <~ channels.producer.map { channels in channels.flatMap({ $0.location }) }

        visibleMapRect <~ userLocation.producer.combineLatest(with: channels.producer).map { [weak self] userLocation, channels in
            var visibleLocations = [CLLocation]()
            if let userLocation = userLocation, let myStore = self?.myStore?.value?.location {
                visibleLocations = [userLocation, myStore]
            } else if let userLocation = userLocation, let nearestStore = channels.first?.location {
                visibleLocations = [userLocation, nearestStore]
            } else {
                visibleLocations = channels.flatMap { $0.location }
            }

            var zoomRect = MKMapRectNull
            let visibleRects = visibleLocations.map { location in
                MKMapRect(origin: MKMapPointForCoordinate(location.coordinate), size: MKMapSize(width: 0.1, height: 0.1))
            }
            visibleRects.forEach {
                zoomRect = MKMapRectUnion(zoomRect, $0)
            }
            return zoomRect
        }

        userLocation.producer.startWithValues({ [weak self] userLocation in
            if let userLocation = userLocation, let stores = self?.channels.value {
                self?.channels.value = Channel.sortStoresByDistance(stores: stores, userLocation: userLocation)
            }
            self?.isLoading.value = false
        })

        refreshSignal
        .observeValues { [weak self] in
            self?.retrieveStores()
        }

        selectedPinCoordinateSignal.observeValues { [weak self] coordinate in
            if let coordinate = coordinate, let store = self?.channels.value.filter({ store in
                if let storeLocation = store.location {
                    return storeLocation.coordinate.latitude == coordinate.latitude
                            && storeLocation.coordinate.longitude == coordinate.longitude
                }
                return false
            }).first {
                self?.storeDetailsViewModel = StoreDetailsViewModel(store: store)
                presentStoreDetailsObserver.send(value: ())
            }
        }

        selectedIndexPathSignal.observeValues { [weak self] indexPath in
            if let store = self?.channels.value[indexPath.row] {
                self?.storeDetailsViewModel = StoreDetailsViewModel(store: store)
                presentStoreDetailsObserver.send(value: ())
            }
        }

        retrieveStores()
    }

    // MARK: - Data Source

    func numberOfRows(in section: Int) -> Int {
        return channels.value.count
    }

    func storeName(at indexPath: IndexPath) -> String {
        return channels.value[indexPath.row].name?.localizedString ?? ""
    }

    func storeDistance(at indexPath: IndexPath) -> String {
        let store = channels.value[indexPath.row]

        if let userLocation = userLocation.value, let storeDistance = store.distance(from: userLocation) {
            return String(format: "%.1f", arguments: [storeDistance / 1000]) + " km"
        }
        return "-"
    }

    func storeImageUrl(at indexPath: IndexPath) -> String {
        return channels.value[indexPath.row].imageUrl ?? ""
    }

    func isMyStore(at indexPath: IndexPath) -> Bool {
        if let myStore = myStore?.value {
            return myStore.id == channels.value[indexPath.row].id
        }
        return false
    }

    // MARK: - Querying for physical stores

    private func retrieveStores() {
        isLoading.value = true

        // Retrieve channels which represent physical stores

        Channel.physicalStores { [weak self] result in
            if let channels = result.model?.results, result.isSuccess {
                self?.channels.value = channels
                if let userLocation = self?.userLocation.value {
                    self?.channels.value = Channel.sortStoresByDistance(stores: channels, userLocation: userLocation)
                }

            } else if let errors = result.errors as? [CTError], let message = self?.alertMessage(for: errors), result.isFailure {
                self?.alertMessageObserver.send(value: message)

            }
            self?.isLoading.value = false
        }
    }

}
