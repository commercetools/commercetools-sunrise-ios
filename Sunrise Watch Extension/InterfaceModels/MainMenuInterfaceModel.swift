//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class MainMenuInterfaceModel {

    // Inputs
    let performSearchObserver: Signal<String, NoError>.Observer

    // Outputs
    let isSignInMessagePresent: MutableProperty<Bool>
    let recentSearches: MutableProperty<[String]>
    let presentSearchResultsSignal: Signal<ProductOverviewInterfaceModel, NoError>

    // Input & Output
    let activeWishList = MutableProperty<ShoppingList?>(nil)

    private let disposables = CompositeDisposable()
    private let kShoppingListVariantExpansion = ["lineItems[*].variant"]
    private let kRecentSearchesKey = "RecentSearchesKey"

    // MARK: - Lifecycle

    init() {
        isSignInMessagePresent = MutableProperty(Commercetools.authState != .customerToken)
        recentSearches = MutableProperty(UserDefaults.standard.array(forKey: kRecentSearchesKey) as? [String] ?? [])
        
        let (performSearchSignal, performSearchObserver) = Signal<String, NoError>.pipe()
        self.performSearchObserver = performSearchObserver
        
        let (presentSearchResultsSignal, presentSearchResultsObserver) = Signal<ProductOverviewInterfaceModel, NoError>.pipe()
        self.presentSearchResultsSignal = presentSearchResultsSignal
        
        disposables += recentSearches.signal
        .observe(on: QueueScheduler())
        .observeValues { [unowned self] in
            UserDefaults.standard.set($0, forKey: self.kRecentSearchesKey)
        }
        
        disposables += performSearchSignal
        .filter { !$0.isEmpty }
        .observeValues { [unowned self] in
            presentSearchResultsObserver.send(value: ProductOverviewInterfaceModel(mainMenuInterfaceModel: self, text: $0))
            var recentSearches = self.recentSearches.value
            if let index = recentSearches.index(of: $0) {
                recentSearches.remove(at: index)
            }
            recentSearches.append($0)
            if recentSearches.count > 3 {
                recentSearches.remove(at: 0)
            }
            self.recentSearches.value = recentSearches
        }

        NotificationCenter.default.addObserver(self, selector: #selector(checkAuthState), name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)

        retrieveActiveWishList()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
        disposables.dispose()
    }

    @objc private func checkAuthState() {
        isSignInMessagePresent.value = Commercetools.authState != .customerToken
    }

    // MARK: - Active WishList

    private func retrieveActiveWishList() {
        let activity = ProcessInfo.processInfo.beginActivity(options: [.background, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve active wish list")
        wishListShoppingList(observer: nil, activity: activity, completion: {
            self.activeWishList.value = $0
        })
    }

    func wishListShoppingList(observer: Signal<Void, CTError>.Observer?, activity: NSObjectProtocol, includeExpansion: Bool = false, completion: @escaping (ShoppingList?) -> Void) {
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
            self.activeWishList.value = result.model?.results.first
        }
    }

    private func createWishListShoppingList(observer: Signal<Void, CTError>.Observer?, activity: NSObjectProtocol, includeExpansion: Bool = false, completion: @escaping (ShoppingList?) -> Void) {
        let draft = ShoppingListDraft(name: ["en": ShoppingList.kWishlistShoppingListName])
        ShoppingList.create(draft, expansion: includeExpansion ? kShoppingListVariantExpansion : []) { result in
            if let error = result.errors?.first as? CTError, result.isFailure {
                observer?.send(error: error)
                observer?.sendCompleted()
                ProcessInfo.processInfo.endActivity(activity)
            }
            completion(result.model)
            self.activeWishList.value = result.model
        }
    }
}
