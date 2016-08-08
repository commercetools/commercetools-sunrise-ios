//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveCocoa
import Result
import ObjectMapper

class StoreSelectionViewModel: BaseViewModel {

    // Inputs
    let selectedIndexPathObserver: Observer<NSIndexPath, NoError>
    let userLocation: MutableProperty<CLLocation?>

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let contentChangesSignal: Signal<Changeset, NoError>
    var channelDetailsIndexPath: NSIndexPath? {
        if let expandedChannelIndexPath = expandedChannelIndexPath.value {
            return NSIndexPath(forRow: expandedChannelIndexPath.row + 1, inSection: expandedChannelIndexPath.section)
        }
        return nil
    }

    // Store information for currently expanded channel
    var streetAndNumberInfo: String {
        if let expandedChannel = expandedChannel, street = expandedChannel.address?.streetName,
                number = expandedChannel.address?.streetNumber {
            return "\(street) \(number)"
        }
        return "-"
    }
    var zipAndCityInfo: String {
        if let expandedChannel = expandedChannel, zip = expandedChannel.address?.postalCode,
                city = expandedChannel.address?.city {
            return "\(zip), \(city)"
        }
        return "-"
    }
    var openLine1Info: String {
        return expandedChannel?.details?.openLine1 ?? "-"
    }
    var openLine2Info: String {
        return expandedChannel?.details?.openLine2 ?? "-"
    }
    var productVariantPrice: String {
        guard let price = currentVariant?.independentPrice, value = price.value else { return "-" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    // Actions
    lazy var reserveAction: Action<NSIndexPath, Void, NSError> = { [unowned self] in
        return Action(enabledIf: ConstantProperty(true), { indexPath in
            self.isLoading.value = true
            return self.reserveProductVariant(self.channels[self.rowForChannelAtIndexPath(indexPath)])
        })
    }()

    // Dialogue texts
    let reservationSuccessTitle = NSLocalizedString("Product has been reserved", comment: "Successful reservation")
    let reservationSuccessMessage = NSLocalizedString("You will get the notification once your product is ready for pickup", comment: "Successful reservation message")
    let reservationContinueTitle = NSLocalizedString("Continue shopping", comment: "Continue shopping")

    private let expandedChannelIndexPath: MutableProperty<NSIndexPath?>
    private let selectedIndexPathSignal: Signal<NSIndexPath, NoError>
    private let contentChangesObserver: Observer<Changeset, NoError>

    var channels: [Channel]
    private var expandedChannel: Channel? {
        if let expandedChannelIndexPath = expandedChannelIndexPath.value {
            return channels[rowForChannelAtIndexPath(expandedChannelIndexPath)]
        }
        return nil
    }
    private var currentVariant: ProductVariant? {
        return product.allVariants.filter({ $0.sku == sku }).first
    }

    private let geocoder = CLGeocoder()
    private var geocodeRequestsTimer: NSTimer?
    private var channelLocations = [Channel: CLLocation]()
    private var processedChannels = Set<Channel>()

    private let product: ProductProjection
    private let sku: String

    // MARK: - Lifecycle

    init(product: ProductProjection, sku: String) {
        self.product = product
        self.sku = sku

        isLoading = MutableProperty(true)
        channels = []
        expandedChannelIndexPath = MutableProperty(nil)
        userLocation = MutableProperty(nil)
        title = NSLocalizedString("Store Location", comment: "Store Location")

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<NSIndexPath, NoError>.pipe()
        self.selectedIndexPathSignal = selectedIndexPathSignal
        self.selectedIndexPathObserver = selectedIndexPathObserver

        let (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        super.init()

        selectedIndexPathSignal
        .observeNext { [unowned self] selectedIndexPath in
            let previouslyExpandedIndexPath = self.expandedChannelIndexPath.value

            if previouslyExpandedIndexPath == selectedIndexPath || self.channelDetailsIndexPath == selectedIndexPath {
                self.expandedChannelIndexPath.value = nil
            } else if let previouslyExpandedIndexPath = previouslyExpandedIndexPath where selectedIndexPath.row > previouslyExpandedIndexPath.row {
                self.expandedChannelIndexPath.value = NSIndexPath(forRow: selectedIndexPath.row - 1, inSection: selectedIndexPath.section)
            } else {
                self.expandedChannelIndexPath.value = selectedIndexPath
            }

            var changeset = Changeset()

            if let channelDetailsIndexPath = self.channelDetailsIndexPath, expandedChannelIndexPath = self.expandedChannelIndexPath.value
                    where previouslyExpandedIndexPath == nil {
                changeset.insertions = [channelDetailsIndexPath]
                changeset.modifications = [expandedChannelIndexPath]
            } else if let previouslyExpandedIndexPath = previouslyExpandedIndexPath where self.expandedChannelIndexPath.value == nil {
                changeset.modifications = [previouslyExpandedIndexPath]
                changeset.deletions = [NSIndexPath(forRow: previouslyExpandedIndexPath.row + 1, inSection: previouslyExpandedIndexPath.section)]
            } else if let channelDetailsIndexPath = self.channelDetailsIndexPath, previouslyExpandedIndexPath = previouslyExpandedIndexPath,
                    expandedChannelIndexPath = self.expandedChannelIndexPath.value {
                let expandedChannelToModify = expandedChannelIndexPath.row > previouslyExpandedIndexPath.row ? NSIndexPath(forRow: expandedChannelIndexPath.row + 1, inSection: expandedChannelIndexPath.section) : expandedChannelIndexPath

                changeset.modifications = [previouslyExpandedIndexPath, expandedChannelToModify]
                changeset.insertions = [channelDetailsIndexPath]
                changeset.deletions = [NSIndexPath(forRow: previouslyExpandedIndexPath.row + 1, inSection: previouslyExpandedIndexPath.section)]
            }
            self.contentChangesObserver.sendNext(changeset)
        }

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

    func reserveButtonEnabledAtIndexPath(indexPath: NSIndexPath) -> Bool {
        let quantity = quantityForChannelAtIndexPath(indexPath)
        return quantity > 0
    }

    func storeDistanceAtIndexPath(indexPath: NSIndexPath) -> String {
        let channel = channels[rowForChannelAtIndexPath(indexPath)]

        if let userLocation = userLocation.value, channelLocation = channelLocations[channel] {
            let distance = userLocation.distanceFromLocation(channelLocation)
            return String(format: "%.1f", arguments: [distance / 1000]) + " km"
        }
        return "-"
    }

    func availabilityAtIndexPath(indexPath: NSIndexPath) -> String {
        let quantity = quantityForChannelAtIndexPath(indexPath)

        switch quantity {
        case 0:
            return NSLocalizedString("not available", comment: "Item not available")
        case 1..<3:
            return NSLocalizedString("hurry up, few items left", comment: "Few items left")
        default:
            return NSLocalizedString("available", comment: "Item available")
        }
    }

    func availabilityColorAtIndexPath(indexPath: NSIndexPath) -> UIColor {
        let quantity = quantityForChannelAtIndexPath(indexPath)

        switch quantity {
        case 0:
            return UIColor(red:1.00, green:0.00, blue:0.00, alpha:1.0)
        case 1..<3:
            return UIColor(red:1.00, green:0.46, blue:0.10, alpha:1.0)
        default:
            return UIColor(red:0.55, green:0.78, blue:0.25, alpha:1.0)
        }
    }

    private func quantityForChannelAtIndexPath(indexPath: NSIndexPath) -> Int {
        if let channelId = channels[rowForChannelAtIndexPath(indexPath)].id {
            return currentVariant?.availability?.channels?[channelId]?.availableQuantity ?? 0
        }
        return 0
    }

    private func rowForChannelAtIndexPath(indexPath: NSIndexPath) -> Int {
        var channelRow = indexPath.row
        if let expandedRow = expandedChannelIndexPath.value?.row where channelRow > expandedRow {
            channelRow -= 1
        }
        return channelRow
    }

    private func indexPathForChannel(channel: Channel) -> NSIndexPath? {
        if var channelRow = channels.indexOf(channel) {
            if let expandedRow = expandedChannelIndexPath.value?.row where channelRow >= expandedRow {
                channelRow += 1
            }
            return NSIndexPath(forRow: channelRow, inSection: 0)
        }
        return nil
    }

    private func retrieveStoreLocations() {
        // We need to deplay each geocoding request due to service limitation
        dispatch_async(dispatch_get_main_queue()) { [unowned self] in
            self.geocodeRequestsTimer?.invalidate()
            self.geocodeRequestsTimer = NSTimer.scheduledTimerWithTimeInterval(0.5, target: self, selector: #selector(self.requestStoreLocation), userInfo: nil, repeats: true)
        }
    }

    @objc private func requestStoreLocation() {
        if processedChannels.count == channels.count {
            geocodeRequestsTimer?.invalidate()
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                var channelsForProcessing = Set(self.channels)
                channelsForProcessing.subtractInPlace(self.processedChannels)
                if let channel = channelsForProcessing.first {
                    if let zip = channel.address?.postalCode, city = channel.address?.city, street = channel.address?.streetName,
                    number = channel.address?.streetNumber, country = channel.address?.country {
                        self.geocoder.geocodeAddressString("\(number) \(street) \(zip) \(city) \(country)", completionHandler: { placemarks, error in
                            if let location = placemarks?.first?.location {
                                self.channelLocations[channel] = location
                                if let indexPath = self.indexPathForChannel(channel) where error == nil {
                                    self.contentChangesObserver.sendNext(Changeset(modifications: [indexPath]))
                                }
                            }
                        })
                    }
                    self.processedChannels.insert(channel)
                }
            }
        }
    }

    // MARK: - Creating a reservation

    private func reserveProductVariant(channel: Channel) -> SignalProducer<Void, NSError> {
        return SignalProducer { observer, disposable in
            guard let channelId = channel.id, productId = self.product.id, currentVariantId = self.currentVariant?.id,
                    shippingAddress = channel.address?.toJSON() else {
                observer.sendFailed(NSError(domain: "Sunrise", code: 1000, userInfo: [NSLocalizedDescriptionKey: "Unexpected product values encountered"]))
                return
            }

            let selectedChannel = ["typeId": "channel", "id": channelId]
            let lineItemDraft: [String: AnyObject] = ["productId": productId,
                                                      "variantId": currentVariantId,
                                                      "supplyChannel": selectedChannel,
                                                      "distributionChannel": selectedChannel]
            let customType = ["type": ["key": "reservationOrder"],
                              "fields": ["isReservation": true]]

            Commercetools.Cart.create(["currency": self.currencyCodeForCurrentLocale,
                                       "shippingAddress": shippingAddress,
                                       "lineItems": [lineItemDraft],
                                       "custom": customType], result: { result in
                if let cart = Mapper<Cart>().map(result.response), id = cart.id, version = cart.version where result.isSuccess {
                    Commercetools.Order.create(["id": id, "version": version], expansion: nil, result: { result in
                        if result.isSuccess {
                            observer.sendCompleted()
                        } else if let error = result.errors?.first where result.isFailure {
                            observer.sendFailed(error)
                        }
                        self.isLoading.value = false
                    })

                } else if let error = result.errors?.first where result.isFailure {
                    observer.sendFailed(error)
                    self.isLoading.value = false
                }
            })
        }
    }

    // MARK: - Querying for physical stores

    private func retrieveStores() {
        isLoading.value = true

        // Retrieve channels which represent physical stores
        Channel.query(predicates: ["roles contains all (\"InventorySupply\", \"ProductDistribution\") AND NOT(roles contains any (\"Primary\"))"],
                sort:  ["lastModifiedAt desc"], result: { result in
            if let results = result.response?["results"] as? [[String: AnyObject]],
            channels = Mapper<Channel>().mapArray(results) where result.isSuccess {
                self.channels = channels
                self.retrieveStoreLocations()

            } else if let errors = result.errors where result.isFailure {
                super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))

            }
            self.isLoading.value = false
        })
    }

}