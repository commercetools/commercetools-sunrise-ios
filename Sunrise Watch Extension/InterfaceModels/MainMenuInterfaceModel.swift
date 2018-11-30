//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class MainMenuInterfaceModel {
    
    enum ProductOverviewType {
        case newProducts
        case onSale
        case wishList
        case search(String)
        
        var rowType: String {
            switch self {
                case .newProducts:
                    return "NewProductsRowType"
                case .onSale:
                    return "OnSaleRowType"
                case .wishList:
                    return "WishListRowType"
                case .search:
                    return "SearchRowType"
            }
        }
        
        var emptyStateInterfaceController: String {
            switch self {
                case .newProducts:
                    return "EmptyNewProductsInterfaceController"
                case .onSale:
                    return "EmptyOnSaleInterfaceController"
                case .wishList:
                    return "EmptyWishListInterfaceController"
                case .search:
                    return "EmptySearchInterfaceController"
            }
        }
    }

    // Inputs
    let showProductOverviewObserver: Signal<ProductOverviewType, NoError>.Observer
    let toggleWishListObserver: Signal<(String, Int?), NoError>.Observer

    // Outputs
    let isSignInMessagePresent: MutableProperty<Bool>
    let recentSearches: MutableProperty<[String]>
    let performProductSegueSignal: Signal<(ProductOverviewType, Int), NoError>
    let presentProductDetailsSignal: Signal<ProductDetailsInterfaceModel, NoError>
    let presentOrderDetailsSignal: Signal<OrderDetailsInterfaceModel, NoError>
    let isLoading = MutableProperty(false)
    let isUpdatingWishList = MutableProperty(false)

    // Input & Output
    let wishListLineItems = MutableProperty([WishListLineItem]())

    private let performProductSegueObserver: Signal<(ProductOverviewType, Int), NoError>.Observer
    private let presentProductDetailsObserver: Signal<ProductDetailsInterfaceModel, NoError>.Observer
    private let presentOrderDetailsObserver: Signal<OrderDetailsInterfaceModel, NoError>.Observer
    private var newProductsInterfaceModel: ProductOverviewInterfaceModel?
    private var onSaleInterfaceModel: ProductOverviewInterfaceModel?
    private var searchInterfaceModel: ProductOverviewInterfaceModel?
    private let disposables = CompositeDisposable()
    private let kShoppingListVariantExpansion = ["lineItems[*].variant"]
    private let kRecentSearchesKey = "RecentSearchesKey"

    // MARK: - Lifecycle

    init() {
        isSignInMessagePresent = MutableProperty(Commercetools.authState != .customerToken)
        recentSearches = MutableProperty(UserDefaults.standard.array(forKey: kRecentSearchesKey) as? [String] ?? [])
        
        let (showProductOverviewSignal, showProductOverviewObserver) = Signal<ProductOverviewType, NoError>.pipe()
        self.showProductOverviewObserver = showProductOverviewObserver
        
        let (toggleWishListSignal, toggleWishListObserver) = Signal<(String, Int?), NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver
        
        (presentProductDetailsSignal, presentProductDetailsObserver) = Signal<ProductDetailsInterfaceModel, NoError>.pipe()
        
        (presentOrderDetailsSignal, presentOrderDetailsObserver) = Signal<OrderDetailsInterfaceModel, NoError>.pipe()
        
        (performProductSegueSignal, performProductSegueObserver) = Signal<(ProductOverviewType, Int), NoError>.pipe()
        
        disposables += recentSearches.signal
        .observe(on: QueueScheduler())
        .observeValues { [unowned self] in
            UserDefaults.standard.set($0, forKey: self.kRecentSearchesKey)
        }
        
        disposables += isSignInMessagePresent.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.newProductsInterfaceModel = ProductOverviewInterfaceModel(type: .newProducts, mainMenuInterfaceModel: self)
            self.onSaleInterfaceModel = ProductOverviewInterfaceModel(type: .onSale, mainMenuInterfaceModel: self)
        }
        
        disposables += showProductOverviewSignal
        .observeValues { [unowned self] in
            self.showProductOverview(type: $0)
        }
        
        disposables += toggleWishListSignal
        .observeValues { [unowned self] productId, variantId in
            self.toggleWishList(productId: productId, variantId: variantId)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(checkAuthState), name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
        disposables.dispose()
    }

    @objc private func checkAuthState() {
        isSignInMessagePresent.value = Commercetools.authState != .customerToken
    }
    
    func detailsInterfaceModel(for row: Int, segueIdentifier: String) -> Any? {
        switch segueIdentifier {
            case newProductsInterfaceModel?.type.rowType:
                return newProductsInterfaceModel?.productDetailsInterfaceModel(for: row)
            case onSaleInterfaceModel?.type.rowType:
                return onSaleInterfaceModel?.productDetailsInterfaceModel(for: row)
            case searchInterfaceModel?.type.rowType:
                return searchInterfaceModel?.productDetailsInterfaceModel(for: row)
            case ProductOverviewType.wishList.rowType:
                return LineItemDetailsInterfaceModel(lineItem: wishListLineItems.value[row], mainMenuInterfaceModel: self)
            default:
                return nil
        }
        
    }
    
    private func showProductOverview(type: ProductOverviewType) {
        isLoading.value = true
        switch type {
            case .newProducts:
                guard let newProductsInterfaceModel = self.newProductsInterfaceModel else { return }
                newProductsInterfaceModel.retrieveProductsObserver.send(value: ())
                disposables += newProductsInterfaceModel.isLoading.producer
                .filter { !$0 }
                .take(first: 1)
                .observe(on: UIScheduler())
                .startWithValues { [weak self] _ in
                    self?.performProductSegueObserver.send(value: (newProductsInterfaceModel.type, newProductsInterfaceModel.numberOfRows.value))
                    self?.isLoading.value = false
                }
            
            case .onSale:
                guard let onSaleInterfaceModel = self.onSaleInterfaceModel else { return }
                onSaleInterfaceModel.retrieveProductsObserver.send(value: ())
                disposables += onSaleInterfaceModel.isLoading.producer
                .filter { !$0 }
                .take(first: 1)
                .observe(on: UIScheduler())
                .startWithValues { [weak self] _ in
                    self?.performProductSegueObserver.send(value: (onSaleInterfaceModel.type, onSaleInterfaceModel.numberOfRows.value))
                    self?.isLoading.value = false
                }
            
            case .search(let term):
                searchInterfaceModel = ProductOverviewInterfaceModel(type: type, mainMenuInterfaceModel: self)
                searchInterfaceModel?.retrieveProductsObserver.send(value: ())
                var recentSearches = self.recentSearches.value
                if let index = recentSearches.index(of: term) {
                    recentSearches.remove(at: index)
                }
                recentSearches.append(term)
                if recentSearches.count > 3 {
                    recentSearches.remove(at: 0)
                }
                self.recentSearches.value = recentSearches
                disposables += searchInterfaceModel!.isLoading.producer
                .filter { !$0 }
                .take(first: 1)
                .observe(on: UIScheduler())
                .startWithValues { [weak self] _ in
                    guard let searchInterfaceModel = self?.searchInterfaceModel else { return }
                    self?.performProductSegueObserver.send(value: (searchInterfaceModel.type, searchInterfaceModel.numberOfRows.value))
                    self?.isLoading.value = false
                }
            
            case .wishList:
                let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Process wish list")
                activeWishList(includeExpansion: true) { list in
                    DispatchQueue.main.async {
                        // Show discounted line items first, then everything else, recently added first
                        self.sortWishListLineItems(lineItems: list?.lineItems)
                        self.isLoading.value = false
                        self.performProductSegueObserver.send(value: (ProductOverviewType.wishList, list?.lineItems.count ?? 0))
                        ProcessInfo.processInfo.endActivity(activity)
                    }
                }
        }
    }
    
    // MARK: - Presenting details interfaces
    
    func showProductDetails(productId: String) {
        isLoading.value = true
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve product")
        activeWishList { _ in
            ProductProjection.byId(productId) { result in
                if let product = result.model, result.isSuccess {
                    self.presentProductDetailsObserver.send(value: ProductProjectionDetailsInterfaceModel(product: product))
                    
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    debugPrint(errors)
                    
                }
                self.isLoading.value = false
                ProcessInfo.processInfo.endActivity(activity)
            }
        }
    }
    
    func showOrderDetails(orderId: String) {
        isLoading.value = true
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve order")
        Order.byId(orderId) { result in
            if let order = result.model, result.isSuccess {
                self.presentOrderDetailsObserver.send(value: OrderDetailsInterfaceModel(order: order))
                
            } else if let errors = result.errors as? [CTError], result.isFailure {
                debugPrint(errors)
                
            }
            self.isLoading.value = false
            ProcessInfo.processInfo.endActivity(activity)
        }
    }

    // MARK: - Active WishList

    func activeWishList(includeExpansion: Bool = false, completion: @escaping (ShoppingList?) -> Void) {
        let activity = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve active wish list")
        wishListShoppingList(activity: activity, includeExpansion: includeExpansion, completion: {
            self.sortWishListLineItems(lineItems: $0?.lineItems)
            completion($0)
        })
    }

    private func wishListShoppingList(observer: Signal<Void, CTError>.Observer? = nil, activity: NSObjectProtocol, includeExpansion: Bool = false, completion: @escaping (ShoppingList?) -> Void) {
        ShoppingList.query(predicates: ["name(en=\"\(ShoppingList.kWishlistShoppingListName)\")"], sort: ["lastModifiedAt desc"], expansion: includeExpansion ? kShoppingListVariantExpansion : [], limit: 1) { result in
            if result.isSuccess, result.model?.count == 0 {
                self.createWishListShoppingList(observer: observer, activity: activity, includeExpansion: includeExpansion, completion: completion)
                return
            }
            if let error = result.errors?.first as? CTError, result.isFailure {
                observer?.send(error: error)
                observer?.sendCompleted()
                ProcessInfo.processInfo.endActivity(activity)
            }
            completion(result.model?.results.first)
        }
    }

    private func createWishListShoppingList<T>(observer: Signal<T, CTError>.Observer?, activity: NSObjectProtocol, includeExpansion: Bool = false, completion: @escaping (ShoppingList?) -> Void) {
        let draft = ShoppingListDraft(name: ["en": ShoppingList.kWishlistShoppingListName])
        ShoppingList.create(draft, expansion: includeExpansion ? kShoppingListVariantExpansion : []) { result in
            if let error = result.errors?.first as? CTError, result.isFailure {
                observer?.send(error: error)
                observer?.sendCompleted()
                ProcessInfo.processInfo.endActivity(activity)
            }
            completion(result.model)
        }
    }
    
    private func toggleWishList(productId: String, variantId: Int?) {
        isUpdatingWishList.value = true
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve wish list")
        let semaphore = DispatchSemaphore(value: 0)
        var wishList: ShoppingList?
        wishListShoppingList(activity: activity, completion: {
            wishList = $0
            semaphore.signal()
        })
        _ = semaphore.wait(timeout: .distantFuture)
        guard let activeWishList = wishList else {
            ProcessInfo.processInfo.endActivity(activity)
            isUpdatingWishList.value = false
            return
        }
        var updatedLineItems = activeWishList.lineItems.map { $0.wishListLineItem }
        let updateAction: ShoppingListUpdateAction
        if let index = activeWishList.lineItems.firstIndex(where: { $0.productId == productId && $0.variantId == variantId }) {
            updateAction = .removeLineItem(lineItemId: activeWishList.lineItems[index].id, quantity: nil)
            // Optimistically update local wish list, while waiting on API response
            updatedLineItems.remove(at: index)
            wishListLineItems.value = updatedLineItems
        } else {
            updateAction = .addLineItem(productId: productId, variantId: variantId, quantity: nil, addedAt: nil, custom: nil)
            // Optimistically update local wish list, while waiting on API response
            updatedLineItems.append(WishListLineItem(id: "", name: [:], productId: productId, variantId: variantId, variant: nil))
            wishListLineItems.value = updatedLineItems
        }
        ShoppingList.update(activeWishList.id, actions: UpdateActions(version: activeWishList.version, actions: [updateAction])) { result in
            if let list = result.model, result.isSuccess {
                self.sortWishListLineItems(lineItems: list.lineItems)
                
            } else if let error = result.errors?.first as? CTError, result.isFailure {
                debugPrint(error)
            }
            self.isUpdatingWishList.value = false
            ProcessInfo.processInfo.endActivity(activity)
        }
    }
    
    /// Shows discounted line items first, then everything else, recently added first
    private func sortWishListLineItems(lineItems: [ShoppingList.LineItem]?) {
        let sortedWishListLineItems = (lineItems?.reversed().sorted(by: { $0.variant?.price()?.discounted?.value.centAmount ?? 0 > $1.variant?.price()?.discounted?.value.centAmount ?? 0 })) ?? []
        wishListLineItems.value = sortedWishListLineItems.map { $0.wishListLineItem }
    }
}

/// Serves for optimistically updating local wish list, while waiting on API response
struct WishListLineItem {
    let id: String
    let name: LocalizedString
    let productId: String
    let variantId: Int?
    let variant: ProductVariant?
}

extension ShoppingList.LineItem {
    var wishListLineItem: WishListLineItem {
        return WishListLineItem(id: id, name: name, productId: productId, variantId: variantId, variant: variant)
    }
}
