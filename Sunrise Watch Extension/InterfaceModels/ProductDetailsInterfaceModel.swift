//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

class ProductDetailsInterfaceModel {

    // Inputs
    var moveToCartAction: Action<Void, Void, CTError>!
    var addToWishListAction: Action<Void, Void, CTError>!

    // Outputs
    let isAddToWishListEnabled = MutableProperty(true)
    var productName: String {
        return product.name.localizedString ?? ""
    }
    var productImageUrl: String {
        return product.displayVariant()?.images?.first?.url ?? ""
    }
    var productPrice: String? {
        guard let variant = product.displayVariant(),
              let price = variant.price() else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }
    var productOldPrice: String {
        guard let variant = product.displayVariant(),
              let price = variant.price(), price.discounted?.value != nil else { return "" }

        return price.value.description
    }
    var userActivityInfo: [AnyHashable: Any]? {
        guard let sku = product.displayVariant()?.sku else { return nil }
        return ["sku": sku]
    }

    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let product: ProductProjection
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(product: ProductProjection, mainMenuInterfaceModel: MainMenuInterfaceModel? = nil) {
        self.product = product
        self.mainMenuInterfaceModel = mainMenuInterfaceModel

        moveToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return self.addToCart()
        }
        
        addToWishListAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return self.addToWishList()
        }
        
        if let mainMenuInterfaceModel = mainMenuInterfaceModel {
            disposables += isAddToWishListEnabled <~ mainMenuInterfaceModel.activeWishList.map { [weak self] in $0?.lineItems.contains(where: { $0.productId == self?.product.id && $0.variantId == self?.product.displayVariant()?.id ?? self?.product.masterVariant.id }) != true }
        }
    }
    
    deinit {
        disposables.dispose()
    }
    
    // MARK: - Add to cart
    
    private func addToCart() -> SignalProducer<Void, CTError> {
        return SignalProducer { [weak self] observer, disposable in
            guard let productId = self?.product.id, let variantId = self?.product.displayVariant()?.id ?? self?.product.masterVariant.id else {
                observer.sendCompleted()
                return
            }
            DispatchQueue.global().async {
                let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Add to cart request")
                ProductDetailsInterfaceModel.queryForActiveCart(observer: observer, activity: activity) { cart in
                    let actions = [CartUpdateAction.addLineItem(lineItemDraft: LineItemDraft(productVariantSelection: .productVariant(productId: productId, variantId: variantId), quantity: 1))]
                    Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: actions), result: { result in
                        if result.isSuccess {
                            observer.send(value: ())
                            
                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                        observer.sendCompleted()
                        ProcessInfo.processInfo.endActivity(activity)
                    })
                }
            }
        }
    }
    
    static func queryForActiveCart(observer: Signal<Void, CTError>.Observer, activity: NSObjectProtocol, completion: ((Cart)->())? = nil) {
        Cart.active(result: { result in
            if let cart = result.model, result.isSuccess {
                // Run recalculation before we present the refreshed cart
                Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: [.recalculate(updateProductData: nil)]), result: { result in
                    if let cart = result.model, result.isSuccess {
                        completion?(cart)
                    } else if let error = result.errors?.first as? CTError, result.isFailure {
                        observer.send(error: error)
                        observer.sendCompleted()
                        ProcessInfo.processInfo.endActivity(activity)
                    }
                })
            } else {
                // If there is no active cart, create one, with the selected product
                let cartDraft = CartDraft(currency: Customer.currentCurrency ?? Locale.currencyCodeForCurrentLocale)
                Cart.create(cartDraft, result: { result in
                    if let cart = result.model, result.isSuccess {
                        completion?(cart)
                    } else if let error = result.errors?.first as? CTError, result.isFailure {
                        observer.send(error: error)
                        observer.sendCompleted()
                        ProcessInfo.processInfo.endActivity(activity)
                    }
                })
            }
        })
    }
    
    // MARK: - Add to WishList
    
    private func addToWishList() -> SignalProducer<Void, CTError> {
        return SignalProducer { [weak self] observer, disposable in
            guard let productId = self?.product.id, let variantId = self?.product.displayVariant()?.id ?? self?.product.masterVariant.id else {
                observer.sendCompleted()
                return
            }
            DispatchQueue.global().async {
                let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Add to wish list request")
                self?.mainMenuInterfaceModel?.wishListShoppingList(observer: observer, activity: activity) { list in
                    guard let list = list, !list.lineItems.contains(where: { $0.productId == productId && $0.variantId == variantId }) else {
                        observer.sendCompleted()
                        ProcessInfo.processInfo.endActivity(activity)
                        return
                    }
                    let actions = [ShoppingListUpdateAction.addLineItem(productId: productId, variantId: variantId, quantity: nil, addedAt: nil, custom: nil)]
                    ShoppingList.update(list.id, actions: UpdateActions(version: list.version, actions: actions)) { result in
                        if let list = result.model, result.isSuccess {
                            self?.mainMenuInterfaceModel?.activeWishList.value = list
                            observer.send(value: ())
                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                        observer.sendCompleted()
                        ProcessInfo.processInfo.endActivity(activity)
                    }
                }
            }
        }
    }
}
