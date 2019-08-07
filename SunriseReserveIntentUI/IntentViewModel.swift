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
    let visibleMapRect = MutableProperty<MKMapRect?>(nil)
    let productName: MutableProperty<String?> = MutableProperty(nil)
    let productImageUrl = MutableProperty("")
    let distance: MutableProperty<String?> = MutableProperty(nil)
    let storeName: MutableProperty<String?> = MutableProperty(nil)
    let openingTimes: MutableProperty<String?> = MutableProperty(nil)
    let storeAddress: MutableProperty<String?> = MutableProperty(nil)
    let size: MutableProperty<String?> = MutableProperty(nil)
    let quantity = MutableProperty<String?>("x1")
    let productColor: MutableProperty<UIColor?> = MutableProperty(nil)
    let price: MutableProperty<NSAttributedString?> = MutableProperty(nil)
    let oldPrice: MutableProperty<NSAttributedString?> = MutableProperty(nil)
    
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
        disposables += oldPrice <~ lineItem.map { lineItem -> NSAttributedString? in
            guard let lineItem = lineItem, lineItem.price.discounted?.value != nil || lineItem.discountedPricePerQuantity.count > 0  else { return nil }
            let oldPriceAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Bold", size: 14)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
            return NSAttributedString(string: lineItem.price.value.description, attributes: oldPriceAttributes)
        }
        disposables += price <~ lineItem.map { lineItem -> NSAttributedString? in
            guard let lineItem = lineItem else { return nil }
            let discountedPriceAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Bold", size: 18)!, .foregroundColor: UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)]
            let regularPriceAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Bold", size: 18)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)]
            if let discounted = lineItem.price.discounted?.value {
                return NSAttributedString(string: discounted.description, attributes: discountedPriceAttributes)

            } else if let discounted = lineItem.discountedPricePerQuantity.first?.discountedPrice.value {
                return NSAttributedString(string: discounted.description, attributes: discountedPriceAttributes)

            } else {
                return NSAttributedString(string: lineItem.price.value.description, attributes: regularPriceAttributes)
            }

        }
        disposables += distance <~ channel.combineLatest(with: userLocation).map { [weak self] store, userLocation -> String? in
            guard let store = store, let userLocation = userLocation, let distance = store.distance(from: userLocation) else { return "-" }
            return self?.distanceFormatter.string(fromDistance: distance)
        }
        
        disposables += visibleMapRect <~ userLocation.combineLatest(with: channel).map { (userLocation, channel) -> MKMapRect? in
            guard let userLocation = userLocation, let channelLocation = channel?.location else { return nil }
            var zoomRect = MKMapRect.null
            let visibleRects = [userLocation, channelLocation].map { location in
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
            guard let previousReservation = result.model, let lineItem = previousReservation.lineItems.first, let channel = lineItem.distributionChannel?.obj, result.isSuccess else {
                self.errorObserver.send(value: ())
                return
            }
            self.isLoading.value = false
            self.lineItem.value = lineItem
            self.channel.value = channel
        }
    }
}
