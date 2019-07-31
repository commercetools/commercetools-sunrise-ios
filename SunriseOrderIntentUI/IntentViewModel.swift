//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import Commercetools
import ReactiveSwift
import Result

class IntentViewModel: BaseViewModel {
    
    // Inputs
    let previousOrderIdObserver: Signal<String, NoError>.Observer
    
    // Outputs
    let numberOfRows = MutableProperty(0)
    let orderTotal = MutableProperty("")
    let errorSignal: Signal<Void, NoError>
    
    private let cart = MutableProperty<Cart?>(nil)
    private let errorObserver: Signal<Void, NoError>.Observer
    private let disposables = CompositeDisposable()
    
    override init() {
        (errorSignal, errorObserver) = Signal<Void, NoError>.pipe()
        let (previousOrderIdSignal, previousOrderIdObserver) = Signal<String, NoError>.pipe()
        self.previousOrderIdObserver = previousOrderIdObserver
        
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        super.init()
        
        disposables += numberOfRows <~ cart.map { $0?.lineItems.count ?? 0 }
        disposables += orderTotal <~ cart.map { [unowned self] in self.orderTotal(for: $0) }
        
        disposables += previousOrderIdSignal
        .observeValues { [weak self] in
            self?.retrieveOrder(by: $0)
        }
    }
    
    deinit {
        disposables.dispose()
    }
    
    private func retrieveOrder(by id: String) {
        Order.byId(id) { result in
            guard let previousOrder = result.model, result.isSuccess else {
                self.errorObserver.send(value: ())
                return
            }
            previousOrder.createReorderCart { cart in
                guard let cart = cart, result.isSuccess else {
                    self.errorObserver.send(value: ())
                    return
                }
                self.cart.value = cart
                Cart.delete(cart.id, version: cart.version) { _ in }
            }
        }
    }
    
    // MARK: - Data Source
    
    func lineItemName(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].name.localizedString ?? ""
    }
    
    func lineItemSize(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.attributes?.filter({ $0.name == "commonSize" }).first?.valueLabel ?? "N/A"
    }
    
    func lineItemImageUrl(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.images?.first?.url ?? ""
    }
    
    func lineItemOldPrice(at indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems[indexPath.row], lineItem.price.discounted?.value != nil || lineItem.discountedPricePerQuantity.count > 0  else { return "" }
        
        return lineItem.price.value.description
    }
    
    func lineItemPrice(at indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems[indexPath.row] else { return "" }
        
        if let discounted = lineItem.price.discounted?.value {
            return discounted.description
            
        } else if let discounted = lineItem.discountedPricePerQuantity.first?.discountedPrice.value {
            return discounted.description
            
        } else {
            return lineItem.price.value.description
        }
    }
    
    func lineItemQuantity(at indexPath: IndexPath) -> String {
        return "x\(cart.value?.lineItems[indexPath.row].quantity ?? 0)"
    }
    
    func lineItemColor(at indexPath: IndexPath) -> UIColor? {
        guard let colorKey = cart.value?.lineItems[indexPath.row].variant.attributes?.filter({ $0.name == "color" }).first?.valueKey else { return nil }
        return UIColor.displayValues[colorKey]
    }
}
