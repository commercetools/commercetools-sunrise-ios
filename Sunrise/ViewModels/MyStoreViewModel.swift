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
    let refreshObserver: Observer<Void, NoError>
    let userLocation: MutableProperty<CLLocation?>

    // Outputs
    let isLoading: MutableProperty<Bool>
    let visibleMapRect: MutableProperty<MKMapRect>
    let selectedStoreLocation: MutableProperty<CLLocation?>
    let storeLocations: MutableProperty<[CLLocation]>
    let selectedStoreName: MutableProperty<String?>
    let selectedStreetAndNumberInfo: MutableProperty<String?>
    let selectedZipAndCityInfo: MutableProperty<String?>
    let selectedOpenLine1Info: MutableProperty<String?>

    private let channels: MutableProperty<[Channel]>


    // MARK: - Lifecycle

    override init() {

        userLocation = MutableProperty(nil)
        isLoading = MutableProperty(true)
        visibleMapRect = MutableProperty(MKMapRectNull)
        selectedStoreLocation = MutableProperty(nil)
        storeLocations = MutableProperty([])
        channels = MutableProperty([])
        selectedStoreName = MutableProperty(nil)
        selectedStreetAndNumberInfo = MutableProperty(nil)
        selectedZipAndCityInfo = MutableProperty(nil)
        selectedOpenLine1Info = MutableProperty(nil)

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<IndexPath?, NoError>.pipe()
        self.selectedIndexPathObserver = selectedIndexPathObserver

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

        selectedIndexPathSignal.observeValues { [weak self] selectedIndexPath in
            if let selectedIndexPath = selectedIndexPath {
                let store = self?.channels.value[selectedIndexPath.row]
                self?.selectedStoreLocation.value = self?.channels.value[selectedIndexPath.row].location
                self?.selectedStoreName.value = store?.name?.localizedString
                self?.selectedStreetAndNumberInfo.value = store?.streetAndNumberInfo
                self?.selectedZipAndCityInfo.value = store?.zipAndCityInfo
                self?.selectedOpenLine1Info.value = store?.openingTimes
            } else {
                self?.selectedStoreLocation.value = nil
                self?.selectedStoreName.value = nil
                self?.selectedStreetAndNumberInfo.value = nil
                self?.selectedZipAndCityInfo.value = nil
                self?.selectedOpenLine1Info.value = nil
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
        // TODO obtain my store from user defaults once store details screen is in place
        return indexPath.row == 0
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
