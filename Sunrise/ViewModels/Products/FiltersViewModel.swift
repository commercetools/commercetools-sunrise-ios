//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result
import Commercetools

class FiltersViewModel: BaseViewModel {

    // Inputs
    let visibleBrandIndex = MutableProperty(IndexPath(item: 0, section: 0))
    let toggleBrandObserver: Signal<IndexPath, NoError>.Observer
    let toggleSizeObserver: Signal<IndexPath, NoError>.Observer
    let toggleColorObserver: Signal<IndexPath, NoError>.Observer
    let toggleMyStyleObserver: Signal<Bool, NoError>.Observer
    let priceRange = MutableProperty((FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax))
    let isActive = MutableProperty(false)
    var scrollBrandAction: Action<Int, IndexPath?, NoError>!
    var resetFiltersAction: Action<Void, Void, NoError>!

    // Outputs
    let isLoading = MutableProperty(true)
    let activeBrandButtonIndex = MutableProperty(0)
    let lowerPrice = MutableProperty("")
    let higherPrice = MutableProperty("")
    let isMyStyleApplied = MutableProperty(false)
    var hasFiltersApplied: Bool {
        return !activeBrands.value.isEmpty || !activeSizes.value.isEmpty || !activeColors.value.isEmpty
                || priceRange.value != (FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax)
    }
    /// The flag indicating whether filters have been manually edited / applied (or are being set by POP to match my style).
    var manuallyAppliedFilters = false

    var priceSetSignal: Signal<Void, NoError>?
    let activeBrands = MutableProperty(Set<String>())
    let activeSizes = MutableProperty(Set<String>())
    let activeColors = MutableProperty(Set<String>())
    let facets: MutableProperty<JsonValue?> = MutableProperty(nil)


    var mainProductType: ProductType?
    private var brands = [AttributeType.EnumValue]()
    private var sizes = [AttributeType.EnumValue]()
    private var colors = [AttributeType.EnumValue]()
    private let disposables = CompositeDisposable()

    static let kPriceMin = 0
    static let kPriceMax = 1000

    // MARK: - Lifecycle

    override init() {
        let (toggleBrandSignal, toggleBrandObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleBrandObserver = toggleBrandObserver

        let (toggleSizeSignal, toggleSizeObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleSizeObserver = toggleSizeObserver

        let (toggleColorSignal, toggleColorObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleColorObserver = toggleColorObserver

        let (toggleMyStyleSignal, toggleMyStyleObserver) = Signal<Bool, NoError>.pipe()
        self.toggleMyStyleObserver = toggleMyStyleObserver

        super.init()

        queryForMainProductType()

        disposables += NotificationCenter.default.reactive.notifications(forName: UIApplication.didBecomeActiveNotification)
        .observeValues { [weak self] _ in
            self?.queryForMainProductType()
        }

        disposables += isLoading <~ activeBrands.map { _ in false }
        disposables += isLoading <~ activeSizes.map { _ in false }
        disposables += isLoading <~ activeColors.map { _ in false }

        disposables += lowerPrice <~ priceRange.map { Money(currencyCode: Customer.currentCurrency ?? "", centAmount: $0.0 * 100).description }
        disposables += higherPrice <~ priceRange.map { Money(currencyCode: Customer.currentCurrency ?? "", centAmount: $0.1 * 100).description + ($0.1 == FiltersViewModel.kPriceMax ? "+" : "") }

        disposables += isLoading.signal.observeValues { [unowned self] _ in
            self.isMyStyleApplied.value = self.isAuthenticated && self.hasFiltersApplied && MyStyleViewModel.brandsSettings == self.activeBrands.value && MyStyleViewModel.sizesSettings == self.activeSizes.value && MyStyleViewModel.colorsSettings == self.activeColors.value
        }

        disposables += facets.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.updateFilters()
        }

        disposables += toggleBrandSignal.observeValues { [unowned self] in
            self.manuallyAppliedFilters = true
            let brand = self.brands[$0.row].key
            if self.activeBrands.value.contains(brand) {
                self.activeBrands.value.remove(brand)
            } else {
                self.activeBrands.value.insert(brand)
            }
        }

        disposables += toggleSizeSignal.observeValues { [unowned self] in
            self.manuallyAppliedFilters = true
            let size = self.sizes[$0.row].key
            if self.activeSizes.value.contains(size) {
                self.activeSizes.value.remove(size)
            } else {
                self.activeSizes.value.insert(size)
            }
        }

        disposables += toggleColorSignal.observeValues { [unowned self] in
            self.manuallyAppliedFilters = true
            let color = self.colors[$0.row].key
            if self.activeColors.value.contains(color) {
                self.activeColors.value.remove(color)
            } else {
                self.activeColors.value.insert(color)
            }
        }

        disposables += NotificationCenter.default.reactive.notifications(forName: Foundation.Notification.Name.Navigation.resetSearch)
        .delay(0.8, on: QueueScheduler())
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            self.resetFilters()
        }

        disposables += activeBrandButtonIndex <~ visibleBrandIndex.map { [unowned self] in
            guard self.brands.count > 0, let firstLetter = self.brandName(at: $0)?.lowercased().first else { return 0 }
            switch firstLetter {
                case "a"..."g":
                    return 0
                case "h"..."q":
                    return 1
                case "r"..."z":
                    return 2
                default:
                    return 3
            }
        }

        scrollBrandAction = Action(enabledIf: Property(value: true)) { [unowned self] buttonIndex -> SignalProducer<IndexPath?, NoError> in
            if let firstMatchingBrand = self.brands.filter({
                guard let firstLetter = $0.stringLabel?.lowercased().first else { return false }
                switch buttonIndex {
                    case 0:
                        return "a"..."g" ~= firstLetter
                    case 1:
                        return "h"..."q" ~= firstLetter
                    case 2:
                        return "r"..."z" ~= firstLetter
                    default:
                        return true
                }
            }).first, let index = self.brands.firstIndex(of: firstMatchingBrand) {
                return SignalProducer(value: IndexPath(item: index, section: 0))
            }
            return SignalProducer(value: nil)
        }

        disposables += toggleMyStyleSignal.observeValues { [unowned self] in
            self.manuallyAppliedFilters = true
            guard self.isAuthenticated else {
                AppRouting.showProfileTab()
                self.isMyStyleApplied.value = false
                return
            }
            if $0 {
                self.activeBrands.value = MyStyleViewModel.brandsSettings
                self.activeSizes.value = MyStyleViewModel.sizesSettings
                self.activeColors.value = MyStyleViewModel.colorsSettings
            } else {
                [self.activeBrands, self.activeSizes, self.activeColors].forEach { $0.value = [] }
            }
            self.isLoading.value = false
        }

        resetFiltersAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            self.resetFilters()
            return SignalProducer(value: ())
        }
    }

    private func resetFilters() {
        manuallyAppliedFilters = false
        updateFilters()
        priceRange.value = (FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax)
        [activeBrands, activeSizes, activeColors].forEach { $0.value = [] }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    var numberOfColors: Int {
        return colors.count
    }

    var numberOfSizes: Int {
        return sizes.count
    }

    var numberOfBrands: Int {
        return brands.count
    }

    func color(at indexPath: IndexPath) -> UIColor? {
        return UIColor.displayValues[colors[indexPath.item].key]
    }

    func isColorActive(at indexPath: IndexPath) -> Bool {
        return activeColors.value.contains(colors[indexPath.item].key)
    }

    func sizeName(at indexPath: IndexPath) -> String? {
        return sizes[indexPath.item].stringLabel
    }

    func isSizeActive(at indexPath: IndexPath) -> Bool {
        return activeSizes.value.contains(sizes[indexPath.item].key)
    }

    func brandName(at indexPath: IndexPath) -> String? {
        return brands[indexPath.item].stringLabel
    }

    func isBrandActive(at indexPath: IndexPath) -> Bool {
        return activeBrands.value.contains(brands[indexPath.item].key)
    }

    // MARK: Attributes extraction

    private func updateFilters() {
        colors = mainProductType?.attributes.filter({ $0.name == Attribute.kColorsAttributeName }).first?.type.values ?? []
        sizes = mainProductType?.attributes.filter({ $0.name == Attribute.kSizeAttributeName }).first?.type.values ?? []
        brands = mainProductType?.attributes.filter({ $0.name == Attribute.kBrandAttributeName }).first?.type.values?.sorted { $0.stringLabel?.lowercased() ?? "" < $1.stringLabel?.lowercased() ?? "" } ?? []

        if let terms = facets.value?.dictionary?["variants.attributes.\(Attribute.kBrandAttributeName).key"]?.dictionary?["terms"]?.array?.map({ $0.dictionary?["term"]?.string ?? "" }) {
            brands = brands.filter({ terms.contains($0.key) }).sorted { $0.stringLabel?.lowercased() ?? "" < $1.stringLabel?.lowercased() ?? "" }
            activeBrands.value = activeBrands.value.filter { terms.contains($0) }
        }

        if let terms = facets.value?.dictionary?["variants.attributes.\(Attribute.kSizeAttributeName).key"]?.dictionary?["terms"]?.array?.map({ $0.dictionary?["term"]?.string ?? "" }) {
            sizes = sizes.filter({ terms.contains($0.key) })
            activeSizes.value = activeSizes.value.filter { terms.contains($0) }
        }

        if let terms = facets.value?.dictionary?["variants.attributes.\(Attribute.kColorsAttributeName).key"]?.dictionary?["terms"]?.array?.map({ $0.dictionary?["term"]?.string ?? "" }) {
            colors = colors.filter({ terms.contains($0.key) })
            activeColors.value = activeColors.value.filter { terms.contains($0) }
        }
    }

    // MARK: - Commercetools attributes querying

    private func queryForMainProductType() {
        isLoading.value = true
        ProductType.query(predicates: ["name = \"main\""]) { [weak self] result in
            DispatchQueue.main.async {
                if let mainProductType = result.model?.results.first {
                    self?.mainProductType = mainProductType
                    self?.updateFilters()
                }
                self?.isLoading.value = false
            }
        }
    }
}

extension AttributeType.EnumValue: Equatable {
    public static func ==(lhs: AttributeType.EnumValue, rhs: AttributeType.EnumValue) -> Bool {
        return lhs.key == rhs.key
    }
}