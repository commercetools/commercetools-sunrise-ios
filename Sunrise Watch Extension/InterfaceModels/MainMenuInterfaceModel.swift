//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Commercetools

class MainMenuInterfaceModel {

    // Inputs

    // Outputs
    let presentSignInMessage: MutableProperty<Bool>

    // Input & Output
    let activeWishList = MutableProperty<ShoppingList?>(nil)

    private let kShoppingListVariantExpansion = ["lineItems[*].variant"]

    // MARK: - Lifecycle

    init() {
        presentSignInMessage = MutableProperty(Commercetools.authState != .customerToken)

        NotificationCenter.default.addObserver(self, selector: #selector(checkAuthState), name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)

        retrieveActiveWishList()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
    }

    @objc private func checkAuthState() {
        presentSignInMessage.value = Commercetools.authState != .customerToken
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
