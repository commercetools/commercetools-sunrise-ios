//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class MainViewModel: BaseViewModel {

    // Due to https://bugs.swift.org/browse/SR-773
    typealias Category = Commercetools.Category

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let selectedCategoryTableRowObserver: Signal<IndexPath, NoError>.Observer
    let selectedCategoryCollectionItemObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let isLoading = MutableProperty(false)
    let activeCategoryName = MutableProperty("")
    let selectedCategoryTableRowSignal: Signal<IndexPath, NoError>
    let selectedCategoryCollectionItemSignal: Signal<IndexPath, NoError>

    let productsViewModel = ProductOverviewViewModel()

    private let rootCategories = MutableProperty([Category]())
    private let activeCategory: MutableProperty<Category?> = MutableProperty(nil)
    private var childCategoriesCache = [String: [Category]]()
    private let categoriesRetrievalQueue = OperationQueue()
    private var categoriesRetrievalSemaphore: DispatchSemaphore?
    private var allCategories = [Category]()
    private var lastRefresh = Date()
    private let kQueryLimit: UInt = 500
    private let disposables = CompositeDisposable()

    private let recentSearchesKey = "recentSearches"
    private var recentSearches: [String] {
        get {
            return (UserDefaults.standard.object(forKey: recentSearchesKey) as? [String]) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: recentSearchesKey)
        }
    }

    // Configuration parameters
    private let navigationExternalId: String? = {
        return Bundle.main.object(forInfoDictionaryKey: "Navigation external ID") as? String
    }()

    private let cacheExpiration: TimeInterval? = {
        return Bundle.main.object(forInfoDictionaryKey: "Category cache expiration") as? TimeInterval
    }()


    // MARK: - Lifecycle

    override init() {
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        (selectedCategoryTableRowSignal, selectedCategoryTableRowObserver) = Signal<IndexPath, NoError>.pipe()
        (selectedCategoryCollectionItemSignal, selectedCategoryCollectionItemObserver) = Signal<IndexPath, NoError>.pipe()

        categoriesRetrievalQueue.maxConcurrentOperationCount = 1

        super.init()

        // set the first root category to be an active one
        disposables += activeCategory <~ rootCategories.map { rootCategories in rootCategories.first }
        disposables += activeCategory <~ selectedCategoryCollectionItemSignal.map { [unowned self] in self.childCategoriesCache[self.activeCategory.value?.id ?? ""]?[$0.item] }
        disposables += activeCategoryName <~ activeCategory.map { $0?.name.localizedString ?? "" }
        disposables += activeCategory <~ selectedCategoryTableRowSignal.map { [unowned self] indexPath -> Category? in
            guard let activeCategory = self.activeCategory.value else { return nil }
            return self.rootCategories.value.contains(activeCategory) ? self.rootCategories.value[indexPath.row] : self.childCategoriesCache[activeCategory.parent?.id ?? ""]?[indexPath.row]
        }
        disposables += activeCategory <~ NotificationCenter.default.reactive.notifications(forName: Foundation.Notification.Name.Navigation.resetSearch).map { [unowned self] _ -> Category? in
            guard let activeCategory = self.activeCategory.value, !self.rootCategories.value.contains(activeCategory) else { return self.activeCategory.value }
            return self.rootCategories.value.filter({ $0.id == activeCategory.parent?.id }).first
        }

        disposables += refreshSignal.observeValues { [weak self] in
            self?.retrieveCategories()
        }

        disposables += activeCategory.producer
        .startWithValues { [unowned self] active in
            guard let active = active, !self.rootCategories.value.contains(active) else { return }
            self.productsViewModel.category.value = active
        }

        disposables += productsViewModel.textSearch.producer
        .filter { $0.0 != "" }
        .startWithValues { [unowned self] in
            if let index = self.recentSearches.index(of: $0.0) {
                self.recentSearches.remove(at: index)
            }
            self.recentSearches.insert($0.0, at: 0)
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: .UIApplicationDidBecomeActive)
        .observeValues { [weak self] _ in
            self?.retrieveCategories()
        }

        retrieveCategories()
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    var numberOfCategoryRows: Int {
        guard let activeCategory = activeCategory.value else { return rootCategories.value.count }
        return rootCategories.value.contains(activeCategory) ? rootCategories.value.count : childCategoriesCache[activeCategory.parent?.id ?? ""]?.count ?? 0
    }

    var numberOfCategoryItems: Int {
        return childCategoriesCache[activeCategory.value?.id ?? ""]?.count ?? 0
    }

    var numberOfRecentSearches: Int {
        return recentSearches.count
    }

    func categoryName(for view: UIScrollView, at indexPath: IndexPath) -> String? {
        guard let activeCategory = activeCategory.value else { return nil }
        if view is UITableView {
            return rootCategories.value.contains(activeCategory) ? rootCategories.value[indexPath.row].name.localizedString : childCategoriesCache[activeCategory.parent?.id ?? ""]?[indexPath.row].name.localizedString
        } else {
            return childCategoriesCache[activeCategory.id]?[indexPath.row].name.localizedString
        }
    }

    func isCategorySelected(at indexPath: IndexPath) -> Bool {
        guard let activeCategory = activeCategory.value else { return false }
        return rootCategories.value.contains(activeCategory) ? rootCategories.value[indexPath.row] == activeCategory : childCategoriesCache[activeCategory.parent?.id ?? ""]?[indexPath.row] == activeCategory
    }

    func recentSearch(at indexPath: IndexPath) -> String {
        return recentSearches[indexPath.row]
    }

    // MARK: - Categories retrieval

    private func retrieveCategories() {
        guard childCategoriesCache.keys.count == 0
                      || (cacheExpiration != nil && lastRefresh.addingTimeInterval(cacheExpiration!) < Date()) else { return }
        categoriesRetrievalQueue.addOperation { [weak self] in
            self?.categoriesRetrievalSemaphore = DispatchSemaphore(value: 0)
            self?.queryForCategories()
            _ = self?.categoriesRetrievalSemaphore?.wait(timeout: DispatchTime.distantFuture)
        }
    }

    private func queryForCategories(offset: UInt = 0) {
        isLoading.value = true
        if offset == 0 {
            allCategories = []
        }

        Category.query(limit: kQueryLimit, offset: offset) { result in
            if let queryResponse = result.model, result.isSuccess {
                let offset = queryResponse.offset
                self.allCategories += queryResponse.results
                if offset + queryResponse.count < queryResponse.total {
                    self.queryForCategories(offset: offset + self.kQueryLimit)
                } else {
                    self.process(categories: self.allCategories)
                    self.isLoading.value = false
                }
            } else if let errors = result.errors as? [CTError], result.isFailure {
                self.isLoading.value = false
                self.categoriesRetrievalSemaphore?.signal()
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
        }
    }

    private func process(categories: [Category]) {
        var rootCategories = [Category]()
        var childCategories = [String: [Category]]()
        var navigationId: String? = nil
        categories.forEach { category in
            let parentCategoryId = category.parent?.id ?? ""
            if category.parent == nil {
                rootCategories.append(category)
            } else if childCategories[parentCategoryId] == nil {
                childCategories[parentCategoryId] = [category]
            } else {
                childCategories[parentCategoryId]?.append(category)
            }

            if category.externalId != nil && category.externalId == navigationExternalId {
                navigationId = category.id
            }
        }
        if let navigationId = navigationId {
            rootCategories = childCategories[navigationId] ?? []
        }
        self.childCategoriesCache = childCategories
        if rootCategories != self.rootCategories.value {
            self.rootCategories.value = rootCategories
        }
        lastRefresh = Date()
        categoriesRetrievalSemaphore?.signal()
    }
}

// For the purpose of this view model, comparing categories by ID and name is sufficient
extension Commercetools.Category: Equatable {
    public static func == (lhs: Commercetools.Category, rhs: Commercetools.Category) -> Bool {
        return lhs.id == rhs.id
    }
}