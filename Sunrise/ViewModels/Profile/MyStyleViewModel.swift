//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import Result
import Commercetools

class MyStyleViewModel: BaseViewModel {

    // Inputs
    let visibleBrandIndex = MutableProperty(IndexPath(item: 0, section: 0))
    let toggleBrandObserver: Signal<IndexPath, NoError>.Observer
    let toggleSizeObserver: Signal<IndexPath, NoError>.Observer
    let toggleColorObserver: Signal<IndexPath, NoError>.Observer
    let isWomen = MutableProperty(isWomenSetting)
    let priceRange = MutableProperty((FiltersViewModel.kPriceMin, FiltersViewModel.kPriceMax))
    var scrollBrandAction: Action<Int, IndexPath?, NoError>!
    var resetSettingsAction: Action<Void, Void, NoError>!
    var saveSettingsAction: Action<Void, Void, NoError>!

    // Outputs
    let isLoading = MutableProperty(true)
    let activeBrandButtonIndex = MutableProperty(0)

    let activeBrands = MutableProperty(brandsSettings)
    let activeSizes = MutableProperty(sizesSettings)
    let activeColors = MutableProperty(colorsSettings)

    static var brandsSettings: Set<String> {
        return Set(UserDefaults.standard.stringArray(forKey: kBrandsSettings) ?? [])
    }
    static var sizesSettings: Set<String> {
        return Set(UserDefaults.standard.stringArray(forKey: kSizesSettings) ?? [])
    }
    static var colorsSettings: Set<String> {
        return Set(UserDefaults.standard.stringArray(forKey: kColorsSettings) ?? [])
    }
    static var isWomenSetting: Bool {
        return UserDefaults.standard.bool(forKey: kIsWomenSettings)
    }

    private var brands = [AttributeType.EnumValue]()
    private var sizes = [AttributeType.EnumValue]()
    private var colors = [AttributeType.EnumValue]()
    private let disposables = CompositeDisposable()

    /// User defaults keys used for storing my style settings.
    private static let kBrandsSettings = "BrandsSettings"
    private static let kSizesSettings = "SizesSettings"
    private static let kColorsSettings = "ColorsSettings"
    private static let kIsWomenSettings = "IsWomenSettings"

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

        disposables += NotificationCenter.default.reactive.notifications(forName: UIApplication.didBecomeActiveNotification)
        .observeValues { [weak self] _ in
            self?.queryForMainProductType()
        }

        disposables += isLoading <~ activeBrands.map { _ in false }
        disposables += isLoading <~ activeSizes.map { _ in false }
        disposables += isLoading <~ activeColors.map { _ in false }

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

        resetSettingsAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return SignalProducer { [unowned self] observer, disposable in
                self.resetSettings()
                observer.send(value: ())
                observer.sendCompleted()
            }
        }

        saveSettingsAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return SignalProducer { [unowned self] observer, disposable in
                UserDefaults.standard.set(Array(self.activeBrands.value), forKey: MyStyleViewModel.kBrandsSettings)
                UserDefaults.standard.set(Array(self.activeSizes.value), forKey: MyStyleViewModel.kSizesSettings)
                UserDefaults.standard.set(Array(self.activeColors.value), forKey: MyStyleViewModel.kColorsSettings)
                UserDefaults.standard.set(self.isWomen.value, forKey: MyStyleViewModel.kIsWomenSettings)
                observer.send(value: ())
                observer.sendCompleted()
            }
        }
    }

    private func resetSettings() {
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
        return FiltersViewModel.colorValues[colors[indexPath.item].key]
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

    private func updateSettings(mainProductType: ProductType) {
        colors = mainProductType.attributes.filter({ $0.name == FiltersViewModel.kColorsAttributeName }).first?.type.values ?? []
        sizes = mainProductType.attributes.filter({ $0.name == FiltersViewModel.kSizeAttributeName }).first?.type.values ?? []
        brands = mainProductType.attributes.filter({ $0.name == FiltersViewModel.kBrandAttributeName }).first?.type.values?.sorted { $0.stringLabel?.lowercased() ?? "" < $1.stringLabel?.lowercased() ?? "" } ?? []
    }

    // MARK: - Commercetools attributes querying

    private func queryForMainProductType() {
        isLoading.value = true
        ProductType.query(predicates: ["name = \"main\""]) { [weak self] result in
            DispatchQueue.main.async {
                if let mainProductType = result.model?.results.first {
                    self?.updateSettings(mainProductType: mainProductType)
                }
                self?.isLoading.value = false
            }
        }
    }
}