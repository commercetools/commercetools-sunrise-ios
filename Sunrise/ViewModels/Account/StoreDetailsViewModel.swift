//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import MapKit
import ReactiveSwift
import Result
import CoreLocation
import Commercetools

class StoreDetailsViewModel: BaseViewModel {

    // Outputs
    let isLoading = MutableProperty(false)
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
    let successTitle = NSLocalizedString("My Store Saved", comment: "My store saved")
    let successMessage: String

    // Actions
    lazy var getDirectionsAction: Action<Void, Void, NoError> = {
        return Action(enabledIf: Property(value: true)) { [weak self] _ in
            return SignalProducer { [weak self] observer, disposable in
                if let location = self?.storeLocation {
                    self?.getDirections(for: location, name: self?.storeName)
                }
                observer.sendCompleted()
            }
        }
    }()
    lazy var saveMyStoreAction: Action<Void, Void, CTError> = {
        return Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return self.saveMyStore()
        }
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

    // MARK: - Saving my store to the customer endpoint

    private func saveMyStore() -> SignalProducer<Void, CTError> {
        isLoading.value = true
        return SignalProducer { [weak self] observer, disposable in
            Customer.addCustomTypeIfNotExists { version, errors in
                if let version = version, errors == nil {
                    let updateActions = UpdateActions(version: version, actions: [CustomerUpdateAction.setCustomField(name: "myStore", value: ["typeId": "channel", "id": self?.store.id ?? ""])])
                    Customer.update(actions: updateActions) { result in
                        self?.isLoading.value = false
                        if result.isSuccess {
                            AppRouting.accountViewController?.viewModel?.currentStore.value = self?.store
                            guard let myStoreId = self?.store.id else { return }
                            UserDefaults.standard.set(myStoreId, forKey: kMyStoreId)
                            observer.sendCompleted()
                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                    }

                } else if let error = errors?.first as? CTError {
                    self?.isLoading.value = false
                    observer.send(error: error)
                }
            }
        }
    }
}
