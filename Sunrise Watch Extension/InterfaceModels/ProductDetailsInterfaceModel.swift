//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveSwift
import Result
import Commercetools

protocol ProductDetailsInterfaceModel: class {
    
    // Inputs
    var moveToCartAction: Action<Void, Void, CTError>! { get }
    var toggleWishListObserver: Signal<Void, NoError>.Observer { get }
    
    // Outputs
    var productName: String { get }
    var productImageUrl: String { get }
    var productPrice: String { get }
    var productOldPrice: String { get }
    var userActivityInfo: [AnyHashable: Any]? { get }
    var isInWishList: MutableProperty<Bool> { get }
    var isWishListButtonEnabled: MutableProperty<Bool> { get }
}

class ReducedProductDetailsInterfaceModel: ProductDetailsInterfaceModel {

    // Inputs
    var moveToCartAction: Action<Void, Void, CTError>!
    let toggleWishListObserver: Signal<Void, NoError>.Observer

    // Outputs
    var productName: String {
        return product.name.localizedString ?? ""
    }
    var productImageUrl: String {
        return product.displayVariant()?.images?.first?.url ?? ""
    }
    var productPrice: String {
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
    let isInWishList = MutableProperty(false)
    let isWishListButtonEnabled = MutableProperty(true)

    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let product: ReducedProduct
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(product: ReducedProduct, mainMenuInterfaceModel: MainMenuInterfaceModel? = nil) {
        self.product = product
        self.mainMenuInterfaceModel = mainMenuInterfaceModel
        
        let (toggleWishListSignal, toggleWishListObserver) = Signal<Void, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver

        moveToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            return ReducedProductDetailsInterfaceModel.addToCart(productId: self.product.id, variantId: self.product.displayVariant()?.id ?? self.product.allVariants.first!.id)
        }
        
        guard let mainMenuInterfaceModel = mainMenuInterfaceModel else { return }
        
        disposables += isInWishList <~ mainMenuInterfaceModel.wishListLineItems.map { $0.contains(where: { $0.productId == product.id && $0.variantId == product.displayVariant()?.id ?? product.allVariants.first!.id }) == true }
        
        disposables += isWishListButtonEnabled <~ mainMenuInterfaceModel.isUpdatingWishList.map { !$0 }
        
        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            self.isWishListButtonEnabled.value = false
            DispatchQueue.global(qos: .userInitiated).async {
                mainMenuInterfaceModel.toggleWishListObserver.send(value: (self.product.id, self.product.displayVariant()?.id ?? self.product.allVariants.first!.id))
            }
        }
    }
    
    deinit {
        disposables.dispose()
    }
}

class LineItemDetailsInterfaceModel: ProductDetailsInterfaceModel {
    
    // Inputs
    var moveToCartAction: Action<Void, Void, CTError>!
    let toggleWishListObserver: Signal<Void, NoError>.Observer
    
    // Outputs
    var productName: String {
        return lineItem.name.localizedString ?? ""
    }
    var productImageUrl: String {
        return lineItem.variant?.images?.first?.url ?? ""
    }
    var productPrice: String {
        guard let variant = lineItem.variant,
            let price = variant.price() else { return "" }
        
        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }
    var productOldPrice: String {
        guard let variant = lineItem.variant,
            let price = variant.price(), price.discounted?.value != nil else { return "" }
        
        return price.value.description
    }
    var userActivityInfo: [AnyHashable: Any]? {
        guard let sku = lineItem.variant?.sku else { return nil }
        return ["sku": sku]
    }
    let isInWishList = MutableProperty(false)
    let isWishListButtonEnabled = MutableProperty(true)
    
    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let lineItem: WishListLineItem
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    init(lineItem: WishListLineItem, mainMenuInterfaceModel: MainMenuInterfaceModel? = nil) {
        self.lineItem = lineItem
        self.mainMenuInterfaceModel = mainMenuInterfaceModel
        
        let (toggleWishListSignal, toggleWishListObserver) = Signal<Void, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver
        
        moveToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] _ in
            guard let variantId = self.lineItem.variantId else {
                return SignalProducer.empty
            }
            return LineItemDetailsInterfaceModel.addToCart(productId: self.lineItem.productId, variantId: variantId)
        }
        
        guard let mainMenuInterfaceModel = mainMenuInterfaceModel else { return }
        
        disposables += isInWishList <~ mainMenuInterfaceModel.wishListLineItems.map { $0.contains(where: { $0.productId == lineItem.productId && $0.variantId == lineItem.variantId }) == true }
        
        disposables += isWishListButtonEnabled <~ mainMenuInterfaceModel.isUpdatingWishList.map { !$0 }
        
        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            self.isWishListButtonEnabled.value = false
            DispatchQueue.global(qos: .userInitiated).async {
                mainMenuInterfaceModel.toggleWishListObserver.send(value: (lineItem.productId, lineItem.variantId))
            }
        }
    }
    
    deinit {
        disposables.dispose()
    }
}

extension ProductDetailsInterfaceModel {
    static func addToCart(productId: String, variantId: Int) -> SignalProducer<Void, CTError> {
        return SignalProducer { observer, disposable in
            DispatchQueue.global().async {
                let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Add to cart request")
                queryForActiveCart(observer: observer, activity: activity) { cart in
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
    
    private static func queryForActiveCart(observer: Signal<Void, CTError>.Observer, activity: NSObjectProtocol, completion: ((Cart)->())? = nil) {
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
}
