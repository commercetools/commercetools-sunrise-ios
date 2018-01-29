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
    let priceRange = MutableProperty((FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax))
    let isActive = MutableProperty(false)
    var scrollBrandAction: Action<Int, IndexPath?, NoError>!
    var resetFiltersAction: Action<Void, Void, NoError>!

    // Outputs
    let isLoading = MutableProperty(true)
    let activeBrandButtonIndex = MutableProperty(0)
    let lowerPrice = MutableProperty("")
    let higherPrice = MutableProperty("")
    var hasFiltersApplied: Bool {
        return !activeBrands.value.isEmpty || !activeSizes.value.isEmpty || !activeColors.value.isEmpty
                || priceRange.value != (FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax)
    }

    var priceSetSignal: Signal<Void, NoError>?
    let activeBrands = MutableProperty(Set<String>())
    let activeSizes = MutableProperty(Set<String>())
    let activeColors = MutableProperty(Set<String>())
    let facets: MutableProperty<JsonValue?> = MutableProperty(nil)

    weak var productsViewModel: ProductOverviewViewModel?

    private var brands = [AttributeType.EnumValue]()
    private var sizes = [AttributeType.EnumValue]()
    private var colors = [AttributeType.EnumValue]()
    private var mainProductType: ProductType?
    private let disposables = CompositeDisposable()

    static let kBrandAttributeName = "designer"
    static let kColorsAttributeName = "color"
    static let kSizeAttributeName = "commonSize"
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

        super.init()

        queryForMainProductType()

        disposables += NotificationCenter.default.reactive.notifications(forName: .UIApplicationDidBecomeActive)
        .observeValues { [weak self] _ in
            self?.queryForMainProductType()
        }

        disposables += isLoading <~ activeBrands.map { _ in false }
        disposables += isLoading <~ activeSizes.map { _ in false }
        disposables += isLoading <~ activeColors.map { _ in false }

        disposables += lowerPrice <~ priceRange.map { [weak self] in Money(currencyCode: self?.productsViewModel?.currentCurrency ?? "", centAmount: $0.0 * 100).description }
        disposables += higherPrice <~ priceRange.map { [weak self] in Money(currencyCode: self?.productsViewModel?.currentCurrency ?? "", centAmount: $0.1 * 100).description + ($0.1 == FiltersViewModel.kPriceMax ? "+" : "") }

        disposables += facets.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            self.updateFilters(from: $0)
        }

        disposables += toggleBrandSignal.observeValues { [unowned self] in
            let brand = self.brands[$0.row].key
            if self.activeBrands.value.contains(brand) {
                self.activeBrands.value.remove(brand)
            } else {
                self.activeBrands.value.insert(brand)
            }
        }

        disposables += toggleSizeSignal.observeValues { [unowned self] in
            let size = self.sizes[$0.row].key
            if self.activeSizes.value.contains(size) {
                self.activeSizes.value.remove(size)
            } else {
                self.activeSizes.value.insert(size)
            }
        }

        disposables += toggleColorSignal.observeValues { [unowned self] in
            let color = self.colors[$0.row].key
            if self.activeColors.value.contains(color) {
                self.activeColors.value.remove(color)
            } else {
                self.activeColors.value.insert(color)
            }
        }

        disposables += NotificationCenter.default.reactive.notifications(forName: Foundation.Notification.Name.Navigation.resetSearch)
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
            }).first, let index = self.brands.index(of: firstMatchingBrand) {
                return SignalProducer(value: IndexPath(item: index, section: 0))
            }
            return SignalProducer(value: nil)
        }

        resetFiltersAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            self.resetFilters()
            return SignalProducer(value: ())
        }
    }

    private func resetFilters() {
        [activeBrands, activeSizes, activeColors].forEach { $0.value = [] }
        updateFilters(from: nil)
        priceRange.value = (FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax)
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
        return colorValues[colors[indexPath.row].key]
    }

    func isColorActive(at indexPath: IndexPath) -> Bool {
        return activeColors.value.contains(colors[indexPath.row].key)
    }

    func sizeName(at indexPath: IndexPath) -> String? {
        return sizes[indexPath.row].stringLabel
    }

    func isSizeActive(at indexPath: IndexPath) -> Bool {
        return activeSizes.value.contains(sizes[indexPath.row].key)
    }

    func brandName(at indexPath: IndexPath) -> String? {
        return brands[indexPath.row].stringLabel
    }

    func isBrandActive(at indexPath: IndexPath) -> Bool {
        return activeBrands.value.contains(brands[indexPath.row].key)
    }

    private let colorValues: [String: UIColor] = ["black": UIColor.black, "grey": UIColor.gray, "beige": UIColor(red: 0.96, green: 0.96, blue: 0.86, alpha: 1.0), "white": .white, "blue": .blue, "brown": .brown, "turquoise": UIColor(red: 0.25, green: 0.88, blue: 0.82, alpha: 1.0), "petrol": UIColor(red: 0.09, green: 0.45, blue: 0.56, alpha: 1.0), "green": .green, "red": .red, "purple": .purple, "pink": UIColor(red: 1.00, green: 0.75, blue: 0.80, alpha: 1.0), "orange": .orange, "yellow": .yellow, "oliv": UIColor(red: 0.50, green: 0.50, blue: 0.00, alpha: 1.0), "gold": UIColor(red: 1.00, green: 0.84, blue: 0.00, alpha: 1.0), "silver": UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0), "multicolored": UIColor(patternImage: #imageLiteral(resourceName: "multicolor"))]

    // MARK: Attributes extraction

    private func updateFilters(from facets: JsonValue?) {
        colors = mainProductType?.attributes.filter({ $0.name == FiltersViewModel.kColorsAttributeName }).first?.type.values ?? []
        sizes = mainProductType?.attributes.filter({ $0.name == FiltersViewModel.kSizeAttributeName }).first?.type.values ?? []
        brands = mainProductType?.attributes.filter({ $0.name == FiltersViewModel.kBrandAttributeName }).first?.type.values?.sorted { $0.stringLabel?.lowercased() ?? "" < $1.stringLabel?.lowercased() ?? "" } ?? []

        if let terms = facets?.dictionary?["variants.attributes.\(FiltersViewModel.kBrandAttributeName).key"]?.dictionary?["terms"]?.array?.map({ $0.dictionary?["term"]?.string ?? "" }) {
            brands = brands.filter({ terms.contains($0.key) }).sorted { $0.stringLabel?.lowercased() ?? "" < $1.stringLabel?.lowercased() ?? "" }
            activeBrands.value = activeBrands.value.filter { terms.contains($0) }
        }

        if let terms = facets?.dictionary?["variants.attributes.\(FiltersViewModel.kSizeAttributeName).key"]?.dictionary?["terms"]?.array?.map({ $0.dictionary?["term"]?.string ?? "" }) {
            sizes = sizes.filter({ terms.contains($0.key) })
            activeSizes.value = activeSizes.value.filter { terms.contains($0) }
        }

        if let terms = facets?.dictionary?["variants.attributes.\(FiltersViewModel.kColorsAttributeName).key"]?.dictionary?["terms"]?.array?.map({ $0.dictionary?["term"]?.string ?? "" }) {
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
                    self?.updateFilters(from: nil)
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