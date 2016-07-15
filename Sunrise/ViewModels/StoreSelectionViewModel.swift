//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ObjectMapper

class StoreSelectionViewModel: BaseViewModel {

    // Inputs
    let expandedChannelIndexPath: MutableProperty<NSIndexPath?>
    let userLocation: MutableProperty<CLLocation?>

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>

    var channels: [Channel]

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(true)

        channels = []

        expandedChannelIndexPath = MutableProperty(nil)

        userLocation = MutableProperty(nil)

        title = NSLocalizedString("Store Location", comment: "Store Location")

        super.init()

        retrieveStores()

    }

    // MARK: - Data Source

    func numberOfRowsInSection(section: Int) -> Int {
        return channels.count + (expandedChannelIndexPath.value != nil ? 1 : 0)
    }

    func storeNameAtIndexPath(indexPath: NSIndexPath) -> String {
        return channels[rowForChannelAtIndexPath(indexPath)].name?.localizedString ?? ""
    }

    func storeImageUrlAtIndexPath(indexPath: NSIndexPath) -> String {
        return channels[rowForChannelAtIndexPath(indexPath)].details?.imageUrl ?? ""
    }

    func expansionTextAtIndexPath(indexPath: NSIndexPath) -> String {
        if indexPath == expandedChannelIndexPath.value {
            return NSLocalizedString("Less info", comment: "Less info")
        } else {
            return NSLocalizedString("More info", comment: "More info")
        }
    }

    func storeDistanceAtIndexPath(indexPath: NSIndexPath) -> String {
        let channel = channels[rowForChannelAtIndexPath(indexPath)]

        if let userLocation = userLocation.value, lat = channel.details?.lat, lon = channel.details?.lon {
            let channelLocation = CLLocation(latitude: lat, longitude: lon)
            let distance = userLocation.distanceFromLocation(channelLocation)
            return String(format: "%.1f", arguments: [distance / 1000]) + " km"
        }
        return "-"
    }

    func availabilityAtIndexPath(indexPath: NSIndexPath) -> String {
        let quantity = 3

        switch quantity {
        case 0:
            return NSLocalizedString("This item is currently not available", comment: "Item not available")
        case 1..<3:
            return NSLocalizedString("Hurry up! Only few items left", comment: "Few items left")
        default:
            return NSLocalizedString("This item is available", comment: "Item available")
        }
    }

    func availabilityColorAtIndexPath(indexPath: NSIndexPath) -> UIColor {
        let quantity = 3

        switch quantity {
        case 0:
            return UIColor(red:1.00, green:0.00, blue:0.00, alpha:1.0)
        case 1..<3:
            return UIColor(red:1.00, green:0.46, blue:0.10, alpha:1.0)
        default:
            return UIColor(red:0.55, green:0.78, blue:0.25, alpha:1.0)
        }
    }

    private func rowForChannelAtIndexPath(indexPath: NSIndexPath) -> Int {
        var channelRow = indexPath.row
        if let expandedRow = expandedChannelIndexPath.value?.row where expandedRow >= channelRow {
            channelRow += 1
        }
        return channelRow
    }

    // MARK: - Creating a reservation

    private func reserveProductVariant() {

    }

    // MARK: - Querying for physical stores

    private func retrieveStores() {
        isLoading.value = true

        // Retrieve channels which represent physical stores
        Channel.query(predicates: ["roles contains all (\"InventorySupply\", \"ProductDistribution\") AND NOT(roles contains any (\"Primary\"))"], result: { result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
            channels = Mapper<Channel>().mapArray(results) where result.isSuccess {
                self.channels = channels

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))

            }
            self.isLoading.value = false
        })
    }

}