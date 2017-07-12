//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class CategoriesViewModel: BaseViewModel {

    // Due to https://bugs.swift.org/browse/SR-773
    typealias Category = Commercetools.Category

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let selectedRowObserver: Signal<IndexPath, NoError>.Observer

    // Outputs
    let isLoading = MutableProperty(false)
    let rootCategoryNames = MutableProperty([String?]())
    let activeRootCategoryName: MutableProperty<String?> = MutableProperty(nil)
    let contentChangesSignal: Signal<Changeset, NoError>
    let performProductOverviewSegueSignal: Signal<IndexPath, NoError>
    let backgroundImage: MutableProperty<UIImage?> = MutableProperty(nil)
    let title = NSLocalizedString("Categories", comment: "Categories")

    // Actions
    lazy var selectRootCategoryAction: Action<String, Void, NoError> = { [unowned self] in
        return Action(enabledIf: Property(value: true)) { categoryName in
            if let rootCategory = self.rootCategories.value.filter({ $0.name.localizedString == categoryName }).first,
               self.activeCategories.value.count == 0 ||
               self.activeCategories.value.first?.name.localizedString != categoryName {
                self.activeCategories.value = [rootCategory]
                self.activeRootCategoryName.value = rootCategory.name.localizedString
            }
            return SignalProducer.empty
        }
    }()

    private let contentChangesObserver: Signal<Changeset, NoError>.Observer

    private let rootCategories = MutableProperty([Category]())
    private let activeCategories = MutableProperty([Category]())
    private var childCategoriesCache = [String: [Category]]()
    private let categoriesRetrievalQueue = OperationQueue()
    private var categoriesRetrievalSemaphore: DispatchSemaphore?
    private var allCategories = [Category]()
    private var lastRefresh = Date()
    private let kQueryLimit: UInt = 500
    private let disposables = CompositeDisposable()

    // Configuration parameters
    private let navigationExternalId: String? = {
        return Bundle.main.object(forInfoDictionaryKey: "Navigation external ID") as? String
    }()

    private let cacheExpiration: TimeInterval? = {
        return Bundle.main.object(forInfoDictionaryKey: "Category cache expiration") as? TimeInterval
    }()


    // MARK: - Lifecycle

    override init() {
        let (performProductOverviewSegueSignal, performProductOverviewSegueObserver) = Signal<IndexPath, NoError>.pipe()
        self.performProductOverviewSegueSignal = performProductOverviewSegueSignal
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        let (selectedRowSignal, selectedRowObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedRowObserver = selectedRowObserver

        categoriesRetrievalQueue.maxConcurrentOperationCount = 1

        super.init()

        rootCategoryNames <~ rootCategories.producer.map { rootCategories in rootCategories.map({ $0.name.localizedString }) }
        // set the first root category to be an active one
        activeCategories <~ rootCategories.producer.map { rootCategories in rootCategories.first != nil ? [rootCategories.first!] : [] }
        activeRootCategoryName <~ activeCategories.producer.map { $0.first?.name.localizedString }
        activeCategories.combinePrevious(activeCategories.value).signal.observeValues { [weak self] previous, current in
            self?.updateActiveCategory(from: previous, to: current)
        }
        // Use hardcoded images till we get assets on categories
        backgroundImage <~ activeCategories.producer.map { (activeCategories: [Category]) -> UIImage? in
            guard let rootCategoryName = activeCategories.first?.name.localizedString else { return nil }
            switch rootCategoryName {
                case "Men":
                    return UIImage(named: "category_men")
                case "Women":
                    return UIImage(named: "category_women")
                default:
                    return UIImage(named: "category_accessories")
            }
        }

        disposables += refreshSignal.observeValues { [weak self] in
            self?.retrieveCategories()
        }

        disposables += selectedRowSignal.observeValues { [weak self] indexPath in
            guard let activeCategoryId = self?.activeCategories.value.last?.id else { return }
            if let activeList = self?.childCategoriesCache[activeCategoryId], self?.activeCategories.value.count == 1 {
                let selectedCategoryId = activeList[indexPath.row].id

                if self?.childCategoriesCache[selectedCategoryId] == nil ||
                   self?.childCategoriesCache[selectedCategoryId]?.count == 0 {
                    performProductOverviewSegueObserver.send(value: indexPath)
                } else {
                    self?.activeCategories.value.append(activeList[indexPath.row])
                }
            } else if let rootCategory = self?.activeCategories.value.first, indexPath.row == 0 {
                self?.activeCategories.value = [rootCategory]
            } else {
                performProductOverviewSegueObserver.send(value: indexPath)
            }
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

    private func updateActiveCategory(from previous: [Category], to current: [Category]) {
        var rangeToDelete = [Int]()
        var rangeToAdd = [Int]()
        var rangeToModify = [Int]()

        // 1. Remove previous list
        if let previousId = previous.last?.id, let previousList = childCategoriesCache[previousId] {
            if let selectedCategory = current.last, previous.count == 1 && current.count > 1 {
                rangeToDelete = (0...previousList.count - 1).filter({ previousList[$0].id != selectedCategory.id })
                rangeToModify = (0...previousList.count - 1).filter({ previousList[$0].id == selectedCategory.id })
            } else if current.count == 1 && previousList.count != 0 || previous.count != 1 {
                rangeToDelete = Array<Int>(previous.count == 1 ? 0...previousList.count - 1 : 0...previousList.count)
            }
        } else if previous.count > 1 && current.count == 1 {
            rangeToDelete = [0]
        }

        // 2. Add new list
        if let currentId = current.last?.id {
            if let currentList = childCategoriesCache[currentId], currentList.count > 0 {
                rangeToAdd = Array<Int>(current.count == 1 ? 0...currentList.count - 1 : 1...currentList.count)
            }
        }
        contentChangesObserver.send(value: Changeset(deletions: rangeToDelete.map({ IndexPath(row: $0, section: 0) }),
                                                    modifications: rangeToModify.map({ IndexPath(row: $0, section: 0) }),
                                                    insertions: rangeToAdd.map({ IndexPath(row: $0, section: 0 ) })))
    }

    func productOverviewViewModelForCategory(at indexPath: IndexPath) -> ProductOverviewViewModel {
        let category = childCategoriesCache[activeCategories.value.last?.id ?? ""]?[activeCategories.value.count >= 2 ? indexPath.row - 1 : indexPath.row]
        return ProductOverviewViewModel(category: category)
    }

    // MARK: - Data Source

    enum CellType {
        case bigCategory
        case smallCategory
    }

    func numberOfRows(in section: Int) -> Int {
        guard let expandedCategoryId = activeCategories.value.last?.id,
              let categoriesToShow = childCategoriesCache[expandedCategoryId] else { return activeCategories.value.count < 2 ? 0 : 1 }
        return activeCategories.value.count < 2 ? categoriesToShow.count : categoriesToShow.count + 1
    }

    func cellType(at indexPath: IndexPath) -> CellType {
        return (activeCategories.value.count >= 2 && indexPath.row > 0) ? .smallCategory : .bigCategory
    }

    func cellRepresentsCollapsibleTitle(at indexPath: IndexPath) -> Bool {
        return activeCategories.value.count >= 2 && indexPath.row == 0
    }

    func categoryName(at indexPath: IndexPath) -> String? {
        if activeCategories.value.count >= 2 && indexPath.row == 0 {
            return activeCategories.value.last?.name.localizedString
        } else if let expandedCategoryId = activeCategories.value.last?.id,
                  let categoriesToShow = childCategoriesCache[expandedCategoryId] {
            return categoriesToShow[activeCategories.value.count >= 2 ? indexPath.row - 1 : indexPath.row].name.localizedString
        }
        return nil
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