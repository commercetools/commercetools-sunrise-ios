//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import ReactiveSwift
import Result
import Commercetools

class WishListInterfaceModel {
    
    // Inputs
    var addToCartAction: Action<Int, Void, CTError>!
    
    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfRows: MutableProperty<Int>
    let presentProductSignal: Signal<ProductDetailsInterfaceModel, NoError>
    
    private weak var mainMenuInterfaceModel: MainMenuInterfaceModel?
    private let presentProductObserver: Signal<ProductDetailsInterfaceModel, NoError>.Observer
    private var lineItems = [ShoppingList.LineItem]()
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    init(mainMenuInterfaceModel: MainMenuInterfaceModel?) {
        self.mainMenuInterfaceModel = mainMenuInterfaceModel
        
        isLoading = MutableProperty(true)
        numberOfRows = MutableProperty(0)
        
        (presentProductSignal, presentProductObserver) = Signal<ProductDetailsInterfaceModel, NoError>.pipe()
        
        if let mainMenuInterfaceModel = mainMenuInterfaceModel {
            disposables += mainMenuInterfaceModel.activeWishList.signal
            .observeValues { [weak self] _  in
                    self?.numberOfRows.value = self?.numberOfRows.value ?? 0
            }
        }
        
        addToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] in
            return self.addToCart(lineItem: self.lineItems[$0])
        }
        
        retrieveWishList()
    }
    
    deinit {
        disposables.dispose()
    }
    
    // MARK: - Data Source
    
    func productImageUrl(at row: Int) -> String {
        return lineItems[row].variant?.images?.first?.url ?? ""
    }
    
    func productName(at row: Int) -> String {
        return lineItems[row].name.localizedString ?? ""
    }
    
    func productPrice(at row: Int) -> String {
        guard let variant = lineItems[row].variant,
              let price = variant.price() else { return "" }
        
        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return price.value.description
        }
    }
    
    // MARK: - Wish list retrieval
    
    private func retrieveWishList() {
        isLoading.value = true
        let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Retrieve wish list")
        mainMenuInterfaceModel?.wishListShoppingList(observer: nil, activity: activity, includeExpansion: true) { list in
            DispatchQueue.main.async {
                self.lineItems = list?.lineItems ?? []
                self.numberOfRows.value = self.lineItems.count
                self.isLoading.value = false
            }
            ProcessInfo.processInfo.endActivity(activity)
        }
    }
    
    // MARK: - Add to cart
    private func addToCart(lineItem: ShoppingList.LineItem) -> SignalProducer<Void, CTError> {
        return SignalProducer { observer, disposable in
            guard let variantId = lineItem.variantId else {
                observer.sendCompleted()
                return
            }
            DispatchQueue.global().async {
                let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .idleSystemSleepDisabled, .suddenTerminationDisabled, .automaticTerminationDisabled], reason: "Add to cart request")
                ProductDetailsInterfaceModel.queryForActiveCart(observer: observer, activity: activity) { cart in
                    let actions = [CartUpdateAction.addLineItem(lineItemDraft: LineItemDraft(productVariantSelection: .productVariant(productId: lineItem.productId, variantId: variantId), quantity: 1))]
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
}
