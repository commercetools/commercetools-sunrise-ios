//
// Copyright (c) 2019 Commercetools. All rights reserved.
//

import Foundation
import Commercetools
import ReactiveSwift
import Result
import MapKit

class IntentViewModel: BaseViewModel {
    
    // Inputs
    let userLocation: MutableProperty<CLLocation?> = MutableProperty(nil)
    
    // Outputs
    let channel = MutableProperty<Channel?>(nil)
    let isLoading = MutableProperty(true)
    let visibleMapRect = MutableProperty(MKMapRect.null)
    let productName: MutableProperty<String?> = MutableProperty(nil)
    let productImageUrl = MutableProperty("")
    let distance: MutableProperty<String?> = MutableProperty(nil)
    let storeName: MutableProperty<String?> = MutableProperty(nil)
    let openingTimes: MutableProperty<String?> = MutableProperty(nil)
    let storeAddress: MutableProperty<String?> = MutableProperty(nil)
    let size: MutableProperty<String?> = MutableProperty(nil)
    let quantity = MutableProperty<String?>("x1")
    let productColor: MutableProperty<UIColor?> = MutableProperty(nil)
    
    // Inputs
    let previousReservationIdObserver: Signal<String, NoError>.Observer
    
    // Outputs
    let numberOfRows = MutableProperty(0)
    let orderTotal = MutableProperty("")
    let errorSignal: Signal<Void, NoError>

    private let lineItem = MutableProperty<LineItem?>(nil)
    private let errorObserver: Signal<Void, NoError>.Observer
    private let distanceFormatter = MKDistanceFormatter()
    private let disposables = CompositeDisposable()
    
    override init() {
        (errorSignal, errorObserver) = Signal<Void, NoError>.pipe()
        let (previousReservationIdSignal, previousReservationIdObserver) = Signal<String, NoError>.pipe()
        self.previousReservationIdObserver = previousReservationIdObserver
        
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        super.init()
        
        distanceFormatter.unitStyle = .abbreviated
        
        disposables += previousReservationIdSignal
        .observeValues { [weak self] in
            self?.retrieveReservation(by: $0)
        }
        
        disposables += productName <~ lineItem.map { $0?.name.localizedString }
        disposables += productImageUrl <~ lineItem.map { $0?.variant.images?.first?.url ?? "" }
        disposables += storeName <~ channel.map { $0?.name?.localizedString }
        disposables += openingTimes <~ channel.map { $0?.openingTimes }
        disposables += storeAddress <~ channel.map { "\($0?.streetAndNumberInfo ?? "")\n\($0?.zipAndCityInfo ?? "")" }
        disposables += size <~ lineItem.map { $0?.variant.attributes?.first(where: { $0.name == Attribute.kSizeAttributeName })?.valueLabel }
        disposables += productColor <~ lineItem.map { (lineItem: LineItem?) -> UIColor? in
            guard let colorValue = lineItem?.variant.attributes?.first(where: { $0.name == Attribute.kColorsAttributeName })?.valueKey else { return nil }
            return Attribute.colorValues[colorValue]
        }
        disposables += distance <~ channel.combineLatest(with: userLocation).map { [weak self] store, userLocation -> String? in
            guard let store = store, let userLocation = userLocation, let distance = store.distance(from: userLocation) else { return "-" }
            return self?.distanceFormatter.string(fromDistance: distance)
        }
        
        disposables += visibleMapRect <~ userLocation.combineLatest(with: channel).map { userLocation, channel in
            var visibleLocations = [CLLocation]()
            if let userLocation = userLocation {
                visibleLocations.append(userLocation)
            }
            if let channelLocation = channel?.location {
                visibleLocations.append(channelLocation)
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
    }
    
    deinit {
        disposables.dispose()
    }
    
    private func retrieveReservation(by id: String) {
        Order.byId(id, expansion: ["lineItems[0].distributionChannel"]) { result in
            self.isLoading.value = false
            guard let previousReservation = result.model, let lineItem = previousReservation.lineItems.first, let channel = lineItem.distributionChannel?.obj, result.isSuccess else {
                self.errorObserver.send(value: ())
                return
            }
            self.lineItem.value = lineItem
            self.channel.value = channel
        }
    }
}
