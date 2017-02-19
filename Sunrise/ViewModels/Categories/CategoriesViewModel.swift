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
    let refreshObserver: Observer<Void, NoError>
    let selectedRowObserver: Observer<IndexPath, NoError>

    // Outputs
    let rootCategoryNames = MutableProperty([String?]())
    let activeRootCategoryName: MutableProperty<String?> = MutableProperty(nil)
    let contentChangesSignal: Signal<Changeset, NoError>
    let backgroundImage: MutableProperty<UIImage?> = MutableProperty(nil)
    let title = NSLocalizedString("Categories", comment: "Categories")

    // Actions
    lazy var selectRootCategoryAction: Action<String, Void, NoError> = { [unowned self] in
        return Action(enabledIf: Property(value: true), { categoryName in
            if let rootCategory = self.rootCategories.value.filter({ $0.name?.localizedString == categoryName }).first,
               self.activeCategories.value.count == 0 ||
               self.activeCategories.value.first?.name?.localizedString != categoryName {
                self.activeCategories.value = [rootCategory]
                self.activeRootCategoryName.value = rootCategory.name?.localizedString
            }
            return SignalProducer.empty
        })
    }()

    private let contentChangesObserver: Observer<Changeset, NoError>

    private let rootCategories = MutableProperty([Category]())
    private let activeCategories = MutableProperty([Category]())
    private let childCategoriesCache = MutableProperty([String: [Category]]())

    // MARK: - Lifecycle

    override init() {
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        let (selectedRowSignal, selectedRowObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedRowObserver = selectedRowObserver

        super.init()

        rootCategoryNames <~ rootCategories.producer.map { rootCategories in rootCategories.map({ $0.name?.localizedString }) }
        // set the first root category to be an active one
        activeCategories <~ rootCategories.producer.map { rootCategories in rootCategories.first != nil ? [rootCategories.first!] : [] }
        activeRootCategoryName <~ activeCategories.producer.map { $0.first?.name?.localizedString }
        activeCategories.combinePrevious(activeCategories.value).signal.observeValues { [weak self] previous, current in
            self?.updateActiveCategory(from: previous, to: current)
        }
        // Use hardcoded images till we get assets on categories
        backgroundImage <~ activeCategories.producer.map { (activeCategories: [Category]) -> UIImage? in
            guard let rootCategoryName = activeCategories.first?.name?.localizedString else { return nil }
            switch rootCategoryName {
                case "Men":
                    return UIImage(named: "category_men")
                case "Women":
                    return UIImage(named: "category_women")
                default:
                    return UIImage(named: "category_accessories")
            }
        }

        refreshSignal.observeValues { [weak self] in
            self?.queryForRootCategories()
        }

        childCategoriesCache.combinePrevious(childCategoriesCache.value).signal.observeValues { [weak self] previous, current in
            if let activeCategories = self?.activeCategories.value, let activeCategoryId = activeCategories.last?.id,
               let categoryList = current[activeCategoryId], categoryList.count > 0, previous[activeCategoryId] == nil {
                let rangeToAdd = activeCategories.count == 1 ? 0...categoryList.count - 1 : 1...categoryList.count
                self?.contentChangesObserver.send(value: Changeset(insertions: rangeToAdd.map({ IndexPath(row: $0, section: 0 )})))
            }
        }

        selectedRowSignal.observeValues { [weak self] indexPath in
            guard let activeCategoryId = self?.activeCategories.value.last?.id else { return }
            if let activeList = self?.childCategoriesCache.value[activeCategoryId], self?.activeCategories.value.count == 1 {
                self?.activeCategories.value.append(activeList[indexPath.row])
            } else if let rootCategory = self?.activeCategories.value.first, indexPath.row == 0 {
                self?.activeCategories.value = [rootCategory]
            }
        }

        queryForRootCategories()
    }

    private func updateActiveCategory(from previous: [Category], to current: [Category]) {
        var rangeToDelete = [Int]()
        var rangeToAdd = [Int]()
        var rangeToModify = [Int]()

        // 1. Remove previous list
        if let previousId = previous.last?.id, let previousList = childCategoriesCache.value[previousId] {
            if let selectedCategory = current.last, previousList.count > 0 && previous.count == 1 && current.count > 1 {
                rangeToDelete = (0...previousList.count - 1).filter({ previousList[$0].id != selectedCategory.id })
                rangeToModify = (0...previousList.count - 1).filter({ previousList[$0].id == selectedCategory.id })
            } else if previousList.count > 0 && current.count == 1 {
                rangeToDelete = Array<Int>(previous.count == 1 ? 0...previousList.count - 1 : 0...previousList.count)
            }
        } else if previous.count > 1 && current.count == 1 {
            rangeToDelete = [0]
        }

        // 2. Add new list
        if let currentId = current.last?.id {
            if let currentList = childCategoriesCache.value[currentId], currentList.count > 0 {
                rangeToAdd = Array<Int>(current.count == 1 ? 0...currentList.count - 1 : 1...currentList.count)
            } else if childCategoriesCache.value[currentId] == nil {
                queryForChildCategories(parentId: currentId)
            }
        }
        contentChangesObserver.send(value: Changeset(deletions: rangeToDelete.map({ IndexPath(row: $0, section: 0) }),
                                                    modifications: rangeToModify.map({ IndexPath(row: $0, section: 0) }),
                                                    insertions: rangeToAdd.map({ IndexPath(row: $0, section: 0 ) })))
    }

    func productOverviewViewModelForCategory(at indexPath: IndexPath) -> ProductOverviewViewModel {
        let category = childCategoriesCache.value[activeCategories.value.last?.id ?? ""]?[indexPath.row - 1]
        return ProductOverviewViewModel(category: category)
    }

    // MARK: - Data Source

    enum CellType {
        case bigCategory
        case smallCategory
    }

    func numberOfRows(in section: Int) -> Int {
        guard let expandedCategoryId = activeCategories.value.last?.id,
              let categoriesToShow = childCategoriesCache.value[expandedCategoryId] else { return activeCategories.value.count < 2 ? 0 : 1 }
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
            return activeCategories.value.last?.name?.localizedString
        } else if let expandedCategoryId = activeCategories.value.last?.id,
                  let categoriesToShow = childCategoriesCache.value[expandedCategoryId] {
            if activeCategories.value.count >= 2 {
                return categoriesToShow[indexPath.row - 1].name?.localizedString
            } else {
                return categoriesToShow[indexPath.row].name?.localizedString
            }
        }
        return nil
    }

    // MARK: - Categories retrieval

    private func queryForRootCategories() {
        Category.query(predicates: ["parent is not defined"]) { result in
            if let categories = result.model?.results, self.rootCategories.value != categories, result.isSuccess {
                self.rootCategories.value = categories
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
        }
    }

    private func queryForChildCategories(parentId: String) {
        Category.query(predicates: ["parent(id = \"\(parentId)\")"]) { result in
            if let categories = result.model?.results, result.isSuccess {
                self.childCategoriesCache.value[parentId] = categories
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
        }
    }
}

// For the purpose of this view model, comparing categories by ID and name is sufficient
extension Commercetools.Category: Equatable {
    public static func == (lhs: Commercetools.Category, rhs: Commercetools.Category) -> Bool {
        return lhs.id == rhs.id && lhs.id != nil && rhs.id != nil
    }
}