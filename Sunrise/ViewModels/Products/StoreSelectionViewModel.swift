//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveSwift
import Result
import CoreLocation
import MapKit

class StoreSelectionViewModel: BaseViewModel {

    // Inputs
    let selectedStoreCoordinate: MutableProperty<CLLocationCoordinate2D?> = MutableProperty(nil)
    let userLocation: MutableProperty<CLLocation?> = MutableProperty(nil)
    var reserveAction: Action<Void, Void, CTError>!

    // Outputs
    let isLoading = MutableProperty(true)
    let visibleMapRect = MutableProperty(MKMapRectNull)
    let storeLocations = MutableProperty([CLLocation]())
    let productName: MutableProperty<String?> = MutableProperty(nil)
    let productImageUrl = MutableProperty("")
    let distance: MutableProperty<String?> = MutableProperty(nil)
    let storeName: MutableProperty<String?> = MutableProperty(nil)
    let openingTimes: MutableProperty<String?> = MutableProperty(nil)
    let storeAddress: MutableProperty<String?> = MutableProperty(nil)
    let size: MutableProperty<String?> = MutableProperty(nil)
    let quantity: MutableProperty<String?> = MutableProperty(nil)
    let isOnStock: MutableProperty<NSAttributedString?> = MutableProperty(nil)
    let productColor: MutableProperty<UIColor?> = MutableProperty(nil)
    let showLoginSignal: Signal<Void, NoError>

    // Dialogue texts
    let outOfStockMessage = NSLocalizedString("Product is not available at the selected store. Try picking a different store.", comment: "Out of Stock")

    var reservationConfirmationViewModel: ReservationConfirmationViewModel? {
        guard let channel = selectedStore.value else { return nil }
        return ReservationConfirmationViewModel(store: channel)
    }

    private var currentVariant: ProductVariant? {
        return product.allVariants.filter({ $0.sku == sku }).first
    }
    private let channels = MutableProperty([Channel]())
    private let selectedStore: MutableProperty<Channel?> = MutableProperty(nil)
    private let product: ProductProjection
    private let sku: String
    private let distanceFormatter = MKDistanceFormatter()
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(product: ProductProjection, sku: String) {
        self.product = product
        self.sku = sku

        let (showLoginSignal, showLoginObserver) = Signal<Void, NoError>.pipe()
        self.showLoginSignal = showLoginSignal

        super.init()

        distanceFormatter.unitStyle = .abbreviated

        productName.value = product.name.localizedString
        size.value = currentVariant?.attributes?.first(where: { $0.name == FiltersViewModel.kSizeAttributeName })?.valueLabel
        if let colorValue = currentVariant?.attributes?.first(where: { $0.name == FiltersViewModel.kColorsAttributeName })?.valueKey {
            productColor.value = FiltersViewModel.colorValues[colorValue]
        }
        productImageUrl.value = currentVariant?.images?.first?.url ?? ""
        quantity.value = "x1"
        disposables += storeLocations <~ channels.map { channels in channels.flatMap({ $0.location }) }
        disposables += selectedStore <~ selectedStoreCoordinate.map { [weak self] selectedCoordinate in self?.channels.value.first { $0.location?.coordinate == selectedCoordinate } }
        disposables += storeName <~ selectedStore.map { $0?.name?.localizedString }
        disposables += openingTimes <~ selectedStore.map { $0?.openingTimes }
        disposables += storeAddress <~ selectedStore.map { "\($0?.streetAndNumberInfo ?? "")\n\($0?.zipAndCityInfo ?? "")" }
        disposables += distance <~ selectedStore.combineLatest(with: userLocation).map { [weak self] store, userLocation -> String? in
            guard let store = store, let userLocation = userLocation, let distance = store.distance(from: userLocation) else { return "-" }
            return self?.distanceFormatter.string(fromDistance: distance)
        }
        disposables += isOnStock <~ selectedStore.map { [unowned self] store -> NSAttributedString? in
            guard let store = store else { return nil }
            if self.currentVariant?.availability?.channels?[store.id]?.isOnStock == true {
                let onStockAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Regular", size: 12)!, .foregroundColor: UIColor(red: 0.38, green: 0.65, blue: 0.08, alpha: 1.0)]
                return NSAttributedString(string: self.onStock, attributes: onStockAttributes)
            } else {
                let notAvailableAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Regular", size: 12)!, .foregroundColor: UIColor(red: 0.82, green: 0.01, blue: 0.11, alpha: 1.0)]
                return NSAttributedString(string: self.notAvailable, attributes: notAvailableAttributes)
            }
        }

        disposables += userLocation.producer
        .startWithValues { [weak self] userLocation in
            if let userLocation = userLocation, let stores = self?.channels.value {
                self?.channels.value = Channel.sortStoresByDistance(stores: stores, userLocation: userLocation)
            }
            self?.isLoading.value = false
        }

        disposables += selectedStoreCoordinate <~ channels.map { channels -> CLLocationCoordinate2D? in channels.first?.location?.coordinate }

        disposables += visibleMapRect <~ userLocation.combineLatest(with: channels).map { userLocation, channels in
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

        reserveAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            if !self.isAuthenticated {
                showLoginObserver.send(value: ())
            } else if self.isOnStock.value?.string == self.notAvailable {
                return SignalProducer(error: CTError.generalError(reason: CTError.FailureReason(message: self.outOfStockMessage, details: nil)))
            } else if let store = self.selectedStore.value {
                self.isLoading.value = true
                return self.reserveProductVariant(store: store)
            }
            return SignalProducer.empty
        }

        retrieveStores()
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Creating a reservation

    private func reserveProductVariant(store: Channel) -> SignalProducer<Void, CTError> {
        return Order.reserveProduct(sku: sku, in: store)
    }

    // MARK: - Querying for physical stores

    private func retrieveStores() {
        isLoading.value = true

        // Retrieve channels which represent physical stores

        Channel.physicalStores { [weak self] result in
            if let channels = result.model?.results, result.isSuccess {
                if let userLocation = self?.userLocation.value {
                    self?.channels.value = Channel.sortStoresByDistance(stores: channels, userLocation: userLocation)
                } else {
                    self?.channels.value = channels
                }

            } else if let errors = result.errors as? [CTError], let message = self?.alertMessage(for: errors), result.isFailure {
                self?.alertMessageObserver.send(value: message)

            }
            self?.isLoading.value = false
        }
    }
}