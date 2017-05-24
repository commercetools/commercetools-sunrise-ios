//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveSwift
import Result
import CoreLocation

class StoreSelectionViewModel: BaseViewModel {

    // Inputs
    let selectedIndexPathObserver: Observer<IndexPath, NoError>
    let refreshObserver: Observer<Void, NoError>
    let userLocation: MutableProperty<CLLocation?>

    // Outputs
    let title: String
    let isLoading: MutableProperty<Bool>
    let contentChangesSignal: Signal<Changeset, NoError>
    var channelDetailsIndexPath: IndexPath? {
        if let expandedChannelIndexPath = expandedChannelIndexPath.value {
            return IndexPath(row: expandedChannelIndexPath.row + 1, section: expandedChannelIndexPath.section)
        }
        return nil
    }

    // Store information for currently expanded channel
    var streetAndNumberInfo: String? {
        return expandedChannel?.streetAndNumberInfo
    }

    var zipAndCityInfo: String? {
        return expandedChannel?.zipAndCityInfo
    }

    var openingTimes: String? {
        return expandedChannel?.openingTimes
    }

    private var productVariantPrice: String {
        guard let price = currentVariant?.independentPrice, let value = price.value else { return "-" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    // Actions
    lazy var reserveAction: Action<IndexPath, Void, CTError> = { [unowned self] in
        return Action(enabledIf: Property(value: true), { indexPath in
            self.isLoading.value = true
            return self.reserveProductVariant(store: self.channels[self.rowForChannelAtIndexPath(indexPath)])
        })
    }()

    private let expandedChannelIndexPath: MutableProperty<IndexPath?>
    private let selectedIndexPathSignal: Signal<IndexPath, NoError>
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

    private let product: ProductProjection
    private let sku: String
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(product: ProductProjection, sku: String) {
        self.product = product
        self.sku = sku

        isLoading = MutableProperty(true)
        channels = []
        expandedChannelIndexPath = MutableProperty(nil)
        userLocation = MutableProperty(nil)
        title = NSLocalizedString("Store Location", comment: "Store Location")

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedIndexPathSignal = selectedIndexPathSignal
        self.selectedIndexPathObserver = selectedIndexPathObserver

        let (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        super.init()

        disposables += selectedIndexPathSignal.observeValues { [unowned self] selectedIndexPath in
            let previouslyExpandedIndexPath = self.expandedChannelIndexPath.value

            if previouslyExpandedIndexPath == selectedIndexPath || self.channelDetailsIndexPath == selectedIndexPath {
                self.expandedChannelIndexPath.value = nil
            } else if let previouslyExpandedIndexPath = previouslyExpandedIndexPath, selectedIndexPath.row > previouslyExpandedIndexPath.row {
                self.expandedChannelIndexPath.value = IndexPath(row: selectedIndexPath.row - 1, section: selectedIndexPath.section)
            } else {
                self.expandedChannelIndexPath.value = selectedIndexPath
            }

            var changeset = Changeset()

            if let channelDetailsIndexPath = self.channelDetailsIndexPath, let expandedChannelIndexPath = self.expandedChannelIndexPath.value,
                    previouslyExpandedIndexPath == nil {
                changeset.insertions = [channelDetailsIndexPath]
                changeset.modifications = [expandedChannelIndexPath]
            } else if let previouslyExpandedIndexPath = previouslyExpandedIndexPath, self.expandedChannelIndexPath.value == nil {
                changeset.modifications = [previouslyExpandedIndexPath]
                changeset.deletions = [IndexPath(row: previouslyExpandedIndexPath.row + 1, section: previouslyExpandedIndexPath.section)]
            } else if let channelDetailsIndexPath = self.channelDetailsIndexPath, let previouslyExpandedIndexPath = previouslyExpandedIndexPath,
                    let expandedChannelIndexPath = self.expandedChannelIndexPath.value {
                let expandedChannelToModify = expandedChannelIndexPath.row > previouslyExpandedIndexPath.row ? IndexPath(row: expandedChannelIndexPath.row + 1, section: expandedChannelIndexPath.section) : expandedChannelIndexPath

                changeset.modifications = [previouslyExpandedIndexPath, expandedChannelToModify]
                changeset.insertions = [channelDetailsIndexPath]
                changeset.deletions = [IndexPath(row: previouslyExpandedIndexPath.row + 1, section: previouslyExpandedIndexPath.section)]
            }
            self.contentChangesObserver.send(value: changeset)
        }

        disposables += refreshSignal.observeValues { [weak self] in
            self?.retrieveStores()
        }

        userLocation.producer
        .startWithValues({ [weak self] userLocation in
            if let userLocation = userLocation, let stores = self?.channels {
                self?.channels = Channel.sortStoresByDistance(stores: stores, userLocation: userLocation)
            }
            self?.isLoading.value = false
        })

        reserveAction.events
        .observeValues({ [weak self] _ in
            self?.isLoading.value = false
        })

        retrieveStores()

    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    func numberOfRowsInSection(_ section: Int) -> Int {
        return channels.count + (expandedChannelIndexPath.value != nil ? 1 : 0)
    }

    func storeNameAtIndexPath(_ indexPath: IndexPath) -> String {
        return channels[rowForChannelAtIndexPath(indexPath)].name?.localizedString ?? ""
    }

    func storeImageUrlAtIndexPath(_ indexPath: IndexPath) -> String {
        return channels[rowForChannelAtIndexPath(indexPath)].imageUrl ?? ""
    }

    func expansionTextAtIndexPath(_ indexPath: IndexPath) -> String {
        if indexPath == expandedChannelIndexPath.value {
            return NSLocalizedString("Less", comment: "Less")
        } else {
            return NSLocalizedString("More", comment: "More")
        }
    }

    func reserveButtonEnabledAtIndexPath(_ indexPath: IndexPath) -> Bool {
        let quantity = quantityForChannelAtIndexPath(indexPath)
        return quantity > 0
    }

    func storeDistanceAtIndexPath(_ indexPath: IndexPath) -> String {
        let store = channels[rowForChannelAtIndexPath(indexPath)]

        if let userLocation = userLocation.value, let storeDistance = store.distance(from: userLocation) {
            return String(format: "%.1f", arguments: [storeDistance / 1000]) + " km"
        }
        return "-"
    }

    func availabilityAtIndexPath(_ indexPath: IndexPath) -> String {
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

    func availabilityColorAtIndexPath(_ indexPath: IndexPath) -> UIColor {
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

    func priceForChannelAtIndexPath(_ indexPath: IndexPath) -> String {
        if let channelId = channels[rowForChannelAtIndexPath(indexPath)].id,
                let price = currentVariant?.prices?.filter({ $0.channel?.id == channelId }).first {
            if let discounted = price.discounted?.value {
                return discounted.description
            } else if let value = price.value {
                return value.description
            }
        }
        return productVariantPrice
    }

    private func quantityForChannelAtIndexPath(_ indexPath: IndexPath) -> Int {
        if let channelId = channels[rowForChannelAtIndexPath(indexPath)].id {
            return currentVariant?.availability?.channels?[channelId]?.availableQuantity ?? 0
        }
        return 0
    }

    private func rowForChannelAtIndexPath(_ indexPath: IndexPath) -> Int {
        var channelRow = indexPath.row
        if let expandedRow = expandedChannelIndexPath.value?.row, channelRow > expandedRow {
            channelRow -= 1
        }
        return channelRow
    }

    private func indexPathForChannel(_ channel: Channel) -> IndexPath? {
        if var channelRow = channels.index(of: channel) {
            if let expandedRow = expandedChannelIndexPath.value?.row, channelRow >= expandedRow {
                channelRow += 1
            }
            return IndexPath(row: channelRow, section: 0)
        }
        return nil
    }

    // MARK: - Creating a reservation

    private func reserveProductVariant(store: Channel) -> SignalProducer<Void, CTError> {
        return Order.reserve(product: product, variant: currentVariant, in: store)
    }

    // MARK: - Querying for physical stores

    private func retrieveStores() {
        isLoading.value = true

        // Retrieve channels which represent physical stores

        Channel.physicalStores { [weak self] result in
            if let channels = result.model?.results, result.isSuccess {
                self?.channels = channels
                if let userLocation = self?.userLocation.value {
                    self?.channels = Channel.sortStoresByDistance(stores: channels, userLocation: userLocation)
                }

            } else if let errors = result.errors as? [CTError], let message = self?.alertMessage(for: errors), result.isFailure {
                self?.alertMessageObserver.send(value: message)

            }
            self?.isLoading.value = false
        }
    }

}
