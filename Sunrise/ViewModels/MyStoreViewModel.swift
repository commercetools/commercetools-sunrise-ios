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
    let selectedIndexPathObserver: Observer<IndexPath?, NoError>
    let selectedPinCoordinateObserver: Observer<CLLocationCoordinate2D?, NoError>
    let refreshObserver: Observer<Void, NoError>
    let userLocation: MutableProperty<CLLocation?>
    let isActive = MutableProperty(true)

    // Outputs
    let isLoading: MutableProperty<Bool>
    let visibleMapRect: MutableProperty<MKMapRect>
    let selectedStoreLocation: MutableProperty<CLLocation?>
    let storeLocations: MutableProperty<[CLLocation]>
//    let selectedStoreDetailsViewModel: MutableProperty<StoreDetailsViewModel?>
    let selectedStoreName: MutableProperty<String?>
    let selectedStreetAndNumberInfo: MutableProperty<String?>
    let selectedZipAndCityInfo: MutableProperty<String?>
    let selectedOpenLine1Info: MutableProperty<String?>
    let presentStoreDetailsSignal: Signal<Void, NoError>
    let backButtonTitle: MutableProperty<String?>
    var backButtonSignal: Signal<Void, NoError>? {
        return AppRouting.accountViewController?.viewModel?.backButtonSignal
    }
    var storeDetailsViewModel: StoreDetailsViewModel? {
        if let store = selectedStore.value {
            return StoreDetailsViewModel(store: store)
        }
        return nil
    }
    var myStore: MutableProperty<Channel?>? {
        return AppRouting.accountViewController?.viewModel?.myStore
    }
    var navigationShouldPop: MutableProperty<Bool>? {
        return AppRouting.accountViewController?.viewModel?.navigationShouldPop
    }

    let selectedStore: MutableProperty<Channel?>
    private let channels: MutableProperty<[Channel]>


    // MARK: - Lifecycle

    override init() {

        userLocation = MutableProperty(nil)
        isLoading = MutableProperty(true)
        visibleMapRect = MutableProperty(MKMapRectNull)
        selectedStoreLocation = MutableProperty(nil)
        storeLocations = MutableProperty([])
        channels = MutableProperty([])
        backButtonTitle = MutableProperty(nil)
        selectedStore = MutableProperty(nil)
        selectedStoreName = MutableProperty(nil)
        selectedStreetAndNumberInfo = MutableProperty(nil)
        selectedZipAndCityInfo = MutableProperty(nil)
        selectedOpenLine1Info = MutableProperty(nil)

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<IndexPath?, NoError>.pipe()
        self.selectedIndexPathObserver = selectedIndexPathObserver

        let (selectedPinCoordinateSignal, selectedPinCoordinateObserver) = Signal<CLLocationCoordinate2D?, NoError>.pipe()
        self.selectedPinCoordinateObserver = selectedPinCoordinateObserver

        let (presentStoreDetailsSignal, presentStoreDetailsObserver) = Signal<Void, NoError>.pipe()
        self.presentStoreDetailsSignal = presentStoreDetailsSignal

        super.init()

        storeLocations <~ channels.producer.map { channels in channels.flatMap({ $0.location }) }

        visibleMapRect <~ userLocation.producer.combineLatest(with: channels.producer).map { userLocation, channels in
            var visibleLocations = [CLLocation]()
            if let userLocation = userLocation, let nearestStore = channels.first?.location {
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

        selectedStoreLocation <~ selectedStore.map { return $0?.location }
        selectedStoreName <~ selectedStore.map { return $0?.name?.localizedString }
        selectedStreetAndNumberInfo <~ selectedStore.map { return $0?.streetAndNumberInfo }
        selectedZipAndCityInfo <~ selectedStore.map { return $0?.zipAndCityInfo }
        selectedOpenLine1Info <~ selectedStore.map { return $0?.openingTimes }
        backButtonTitle <~ selectedStore.combineLatest(with: isActive).map { selectedStore, isActive in
            selectedStore == nil || !isActive ? NSLocalizedString("My Account", comment: "My Account") : NSLocalizedString("All Stores", comment: "All Stores")
        }
        if let navigationShouldPop = navigationShouldPop {
            navigationShouldPop <~ selectedStore.combineLatest(with: isActive).map { selectedStore, isActive in
                return selectedStore == nil || !isActive
            }
        }
        if let backButtonSignal = backButtonSignal {
            backButtonSignal.observeValues { [weak self] in
                if let isActive = self?.isActive.value, self?.selectedStore.value != nil && isActive {
                    self?.selectedStore.value = nil
                }
            }
        }

        selectedIndexPathSignal.observeValues { [weak self] selectedIndexPath in
            if let selectedIndexPath = selectedIndexPath {
                self?.selectedStore.value = self?.channels.value[selectedIndexPath.row]
            } else {
                self?.selectedStore.value = nil
            }
        }

        selectedPinCoordinateSignal.observeValues { [weak self] coordinate in
            if self?.selectedStore.value != nil {
                presentStoreDetailsObserver.send(value: ())
            } else if let coordinate = coordinate {
                self?.selectedStore.value = self?.channels.value.filter({ store in
                    if let storeLocation = store.location {
                        return storeLocation.coordinate.latitude == coordinate.latitude
                                && storeLocation.coordinate.longitude == coordinate.longitude
                    }
                    return false
                }).first
            } else {
                self?.selectedStore.value = nil
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
