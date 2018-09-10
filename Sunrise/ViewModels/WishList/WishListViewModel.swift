//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class WishListViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let addToBagObserver: Signal<IndexPath, NoError>.Observer
    let deleteObserver: Signal<IndexPath, NoError>.Observer
    var toggleWishListAction: Action<(String, Int?), Void, CTError>!

    // Outputs
    let isLoading = MutableProperty(false)
    let contentChangesSignal: Signal<Changeset, NoError>

    let lineItems = MutableProperty([ShoppingList.LineItem]())
    private let contentChangesObserver: Signal<Changeset, NoError>.Observer
    private let kShoppingListVariantExpansion = ["lineItems[*].variant"]
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (addToBagSignal, addToBagObserver) = Signal<IndexPath, NoError>.pipe()
        self.addToBagObserver = addToBagObserver

        let (deleteSignal, deleteObserver) = Signal<IndexPath, NoError>.pipe()
        self.deleteObserver = deleteObserver

        super.init()

        disposables += lineItems.signal
        .observe(on: UIScheduler())
        .observeValues {
            SunriseTabBarController.currentlyActive?.wishListBadge = $0.count
        }

        disposables += refreshSignal.observeValues { [unowned self] in
            self.queryForWishListLineItems()
        }

        disposables += addToBagSignal.observeValues { [unowned self] in
            self.isLoading.value = true
            let lineItem = self.lineItems.value[$0.row]
            self.disposables += AppRouting.cartViewController?.viewModel?.addToCartAction.apply((lineItem.productId, lineItem.variantId ?? 0)).start()
        }

        disposables += deleteSignal.observeValues { [unowned self] in
            let lineItem = self.lineItems.value[$0.row]
            self.remove(lineItem: lineItem)
        }

        toggleWishListAction = Action(enabledIf: Property(value: true)) { [unowned self] productId, variantId -> SignalProducer<Void, CTError> in
            self.isLoading.value = true
            return self.toggleWishList(productId: productId, variantId: variantId)
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    var numberOfLineItems: Int {
        return lineItems.value.count
    }

    func lineItemName(at indexPath: IndexPath) -> String {
        return lineItems.value[indexPath.row].name.localizedString ?? ""
    }

    func lineItemImageUrl(at indexPath: IndexPath) -> String {
        return lineItems.value[indexPath.row].variant?.images?.first?.url ?? ""
    }

    func lineItemOldPrice(at indexPath: IndexPath) -> String {
        guard let price = lineItems.value[indexPath.row].variant?.price(), price.discounted?.value != nil else { return "" }
        return price.value.description
    }

    func lineItemPrice(at indexPath: IndexPath) -> String {
        guard let price = lineItems.value[indexPath.row].variant?.price() else { return "" }
        return price.discounted?.value.description ?? price.value.description
    }

    func lineItemSku(at indexPath: IndexPath) -> String? {
        return lineItems.value[indexPath.row].variant?.sku
    }

    // MARK: - WishList retrieval

    private func queryForWishListLineItems() {
        isLoading.value = true
        wishListShoppingList { list in
            self.update(lineItems: list?.lineItems ?? [])
            self.isLoading.value = false
        }
    }

    private func wishListShoppingList(_ completion: @escaping (ShoppingList?) -> Void) {
        ShoppingList.query(predicates: ["name(en=\"\(ShoppingList.kWishlistShoppingListName)\")"], sort: ["lastModifiedAt desc"], expansion: kShoppingListVariantExpansion, limit: 1) { result in
            if result.isSuccess, result.model?.count == 0 {
                self.createWishListShoppingList(completion)
                return
            }
            if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            completion(result.model?.results.first)
        }
    }

    private func createWishListShoppingList(_ completion: @escaping (ShoppingList?) -> Void) {
        let draft = ShoppingListDraft(name: ["en": ShoppingList.kWishlistShoppingListName])
        ShoppingList.create(draft, expansion: kShoppingListVariantExpansion) { result in
            if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
            completion(result.model)
        }
    }

    // MARK: - Toggling WishList items

    func toggleWishList(productId: String, variantId: Int?) -> SignalProducer<Void, CTError> {
        return SignalProducer { [unowned self] observer, disposable in
            DispatchQueue.global().async {
                self.wishListShoppingList { list in
                    guard let list = list else {
                        observer.sendCompleted()
                        return
                    }
                    var actions = [ShoppingListUpdateAction]()
                    if let lineItem = self.lineItems.value.first(where: { $0.productId == productId && $0.variantId == variantId }) {
                        actions.append(.removeLineItem(lineItemId: lineItem.id, quantity: nil))
                    } else {
                        actions.append(.addLineItem(productId: productId, variantId: variantId, quantity: nil, addedAt: nil, custom: nil))
                    }
                    ShoppingList.update(list.id, actions: UpdateActions(version: list.version, actions: actions), expansion: self.kShoppingListVariantExpansion) { result in
                        if let list = result.model, result.isSuccess {
                            self.update(lineItems: list.lineItems)
                            observer.send(value: ())
                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                        self.isLoading.value = false
                        observer.sendCompleted()
                    }
                }
            }
        }
    }

    private func remove(lineItem: ShoppingList.LineItem) {
        isLoading.value = true
        wishListShoppingList { list in
            guard let list = list else { return }
            let updateActions = UpdateActions(version: list.version, actions: [ShoppingListUpdateAction.removeLineItem(lineItemId: lineItem.id, quantity: nil)])
            ShoppingList.update(list.id, actions: updateActions, expansion: self.kShoppingListVariantExpansion) { result in
                if let list = result.model, result.isSuccess {
                    self.update(lineItems: list.lineItems)
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                }
                self.isLoading.value = false
            }
        }
    }

    // MARK: - Calculating changeset based on old and new `lineItems` array values

    private func update(lineItems: [ShoppingList.LineItem]) {
        var changeset = Changeset()

        let oldLineItems = self.lineItems.value
        let newLineItems = lineItems

        var deletions = [IndexPath]()
        var modifications = [IndexPath]()
        for (i, lineItem) in oldLineItems.enumerated() {
            if !newLineItems.contains(lineItem) {
                deletions.append(IndexPath(row: i, section:0))
            } else {
                modifications.append(IndexPath(row: i, section:0))
            }
        }
        changeset.deletions = deletions
        changeset.modifications = modifications

        var insertions = [IndexPath]()
        for (i, lineItem) in newLineItems.enumerated() {
            if !oldLineItems.contains(lineItem) {
                insertions.append(IndexPath(row: i, section:0))
            }
        }
        changeset.insertions = insertions

        self.lineItems.value = lineItems
        contentChangesObserver.send(value: changeset)
    }
}
