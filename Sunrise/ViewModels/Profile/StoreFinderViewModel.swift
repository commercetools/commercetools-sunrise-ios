//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import CoreLocation
import MapKit

class StoreFinderViewModel: BaseViewModel {
    
    // Inputs
    let textSearch = MutableProperty<String?>(nil)
    let userLocation: MutableProperty<CLLocation?> = MutableProperty(nil)
    let selectedStoreCoordinate: MutableProperty<CLLocationCoordinate2D?> = MutableProperty(nil)
    let selectedStoreObserver: Signal<IndexPath, NoError>.Observer
    let deselectedStoreObserver: Signal<Void, NoError>.Observer
    var setAsDefaultStoreAction: Action<Void, Void, NoError>!

    // Outputs
    let isLoading = MutableProperty(true)
    let visibleMapRect = MutableProperty(MKMapRect.null)
    let isStoreDetailsVisible = MutableProperty(false)
    let storeLocations = MutableProperty([CLLocation]())
    let selectedStoreName = MutableProperty("")
    let selectedStoreDistance = MutableProperty("")
    let selectedStoreAddress = MutableProperty("")
    let selectedStoreOpenHours = MutableProperty("")
    let isSelectedStoreDefault = MutableProperty(false)


    private let selectedStore: MutableProperty<Channel?> = MutableProperty(nil)
    private let stores = MutableProperty([Channel]())
    private var allStores = [Channel]()
    private let kDefaultStoreId = "MyStoreId"
    private var defaultStoreId: String? {
        get {
            return UserDefaults.standard.string(forKey: kDefaultStoreId)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: kDefaultStoreId)
        }
    }
    private let distanceFormatter = MKDistanceFormatter()
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    override init() {
        let (selectedStoreSignal, selectedStoreObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedStoreObserver = selectedStoreObserver

        let (deselectedStoreSignal, deselectedStoreObserver) = Signal<Void, NoError>.pipe()
        self.deselectedStoreObserver = deselectedStoreObserver

        super.init()

        distanceFormatter.unitStyle = .abbreviated

        disposables += storeLocations <~ stores.map { stores in stores.compactMap({ $0.location }) }

        disposables += selectedStore <~ selectedStoreCoordinate.map { [weak self] selectedCoordinate in self?.stores.value.first { $0.location?.coordinate == selectedCoordinate } }

        disposables += selectedStoreCoordinate <~ selectedStoreSignal.map { [weak self] in self?.stores.value[$0.row].location?.coordinate }

        disposables += selectedStoreCoordinate <~ deselectedStoreSignal.map { nil }

        disposables += isLoading <~ selectedStore.map { _ in false }

        disposables += selectedStoreName <~ selectedStore.map { $0?.name?.localizedString ?? "" }

        disposables += selectedStoreAddress <~ selectedStore.map { "\($0?.streetAndNumberInfo ?? "")\n\($0?.zipAndCityInfo ?? "")" }

        disposables += selectedStoreOpenHours <~ selectedStore.map { $0?.openingTimes ?? "" }

        disposables += isSelectedStoreDefault <~ selectedStore.map { [unowned self] in $0?.id == self.defaultStoreId }

        disposables += selectedStoreCoordinate.combinePrevious(nil).producer
        .filter { $0 != nil || $1 != nil }
        .startWithValues { [unowned self] in
            guard $0?.latitude == $1?.latitude, $0?.longitude == $1?.longitude, self.isStoreDetailsVisible.value == false else { return }
            self.isStoreDetailsVisible.value = true
        }

        disposables += selectedStoreDistance <~ selectedStore.map { [unowned self] in
            guard let userLocation = self.userLocation.value, let distance = $0?.distance(from: userLocation) else { return "-" }
            return self.distanceFormatter.string(fromDistance: distance)
        }

        disposables += userLocation.producer
        .startWithValues { [weak self] userLocation in
            if let userLocation = userLocation, let stores = self?.stores.value {
                self?.stores.value = Channel.sortStoresByDistance(stores: stores, userLocation: userLocation)
            }
            self?.isLoading.value = false
        }

        disposables += textSearch.producer
        .startWithValues { [weak self] _ in self?.filterStores() }

        disposables += selectedStoreCoordinate <~ stores.map { stores -> CLLocationCoordinate2D? in stores.first?.location?.coordinate }

        disposables += visibleMapRect <~ userLocation.combineLatest(with: stores).combineLatest(with: selectedStore).map {
            var visibleLocations = [CLLocation]()
            let nearestStore = $0.1?.location ?? $0.0.1.first?.location
            if let userLocation = $0.0.0, let nearestStore = nearestStore {
                visibleLocations = [userLocation, nearestStore]
            } else if let nearestStore = nearestStore {
                visibleLocations = [nearestStore]
            } else {
                visibleLocations = $0.0.1.compactMap { $0.location }
            }

            var zoomRect = MKMapRect.null
            let visibleRects = visibleLocations.map { location in
                MKMapRect(origin: MKMapPoint(location.coordinate), size: MKMapSize(width: 0.1, height: 0.1))
            }
            visibleRects.forEach {
                zoomRect = zoomRect.union($0)
            }
            return zoomRect
        }

        setAsDefaultStoreAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            self.defaultStoreId = self.selectedStore.value?.id
            self.isSelectedStoreDefault.value = true
            return SignalProducer.empty
        }

        retrieveStores()
    }
    
    deinit {
        disposables.dispose()
    }
    
    // MARK: - Data Source
    
    var numberOfStores: Int {
        return stores.value.count
    }

    func isSelected(at indexPath: IndexPath) -> Bool {
        return stores.value[indexPath.row] == selectedStore.value
    }

    func address(at indexPath: IndexPath) -> String? {
        let store = stores.value[indexPath.row]
        return "\(store.streetAndNumberInfo)\n\(store.zipAndCityInfo)"
    }

    func distance(at indexPath: IndexPath) -> String? {
        guard let userLocation = userLocation.value, let distance = stores.value[indexPath.row].distance(from: userLocation) else { return "-" }
        return distanceFormatter.string(fromDistance: distance)
    }

    // MARK: - Filtering by store name

    func filterStores() {
        let filteredStores = textSearch.value != nil && !textSearch.value!.isEmpty ? allStores.filter { $0.name?.localizedString?.lowercased().contains(textSearch.value!.lowercased()) == true } : allStores
        if let userLocation = userLocation.value {
            stores.value = Channel.sortStoresByDistance(stores: filteredStores, userLocation: userLocation)
        } else {
            stores.value = filteredStores
        }
    }

    // MARK: - Querying for physical stores

    private func retrieveStores() {
        isLoading.value = true

        // Retrieve channels which represent physical stores

        Channel.physicalStores { [weak self] result in
            if let channels = result.model?.results, result.isSuccess {
                self?.allStores = channels
                self?.filterStores()

            } else if let errors = result.errors as? [CTError], let message = self?.alertMessage(for: errors), result.isFailure {
                self?.alertMessageObserver.send(value: message)

            }
            self?.isLoading.value = false
        }
    }
}