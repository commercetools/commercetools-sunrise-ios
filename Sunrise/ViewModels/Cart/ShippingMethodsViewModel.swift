//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class ShippingMethodsViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>
    let selectedIndexPathObserver: Observer<IndexPath, NoError>

    // Outputs
    let isLoading = MutableProperty(false)
    let performSegueSignal: Signal<Void, NoError>

    private var methods: MutableProperty<[ShippingMethod]>
    private let performSegueObserver: Observer<Void, NoError>
    private var cart: Cart?
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    init(shippingMethods: [ShippingMethod] = [], cart: Cart? = nil) {
        methods = MutableProperty(shippingMethods)
        self.cart = cart

        (performSegueSignal, performSegueObserver) = Signal<Void, NoError>.pipe()

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (selectedIndexPathSignal, selectedIndexPathObserver) = Signal<IndexPath, NoError>.pipe()
        self.selectedIndexPathObserver = selectedIndexPathObserver

        super.init()

        disposables += refreshSignal.observeValues { [weak self] in
            self?.retrieveShippingMethods()
        }

        disposables += selectedIndexPathSignal.observeValues { [weak self] indexPath in
            self?.addShippingMethodToCart(at: indexPath)
        }

        if shippingMethods.count == 0 {
            retrieveShippingMethods()
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    func numberOfRows(in section: Int) -> Int {
        return methods.value.count
    }

    func nameAndDescription(at indexPath: IndexPath) -> String? {
        let method = methods.value[indexPath.row]
        let name = method.name
        let description = method.description ?? ""
        return "\(name) \(description)"
    }

    func price(at indexPath: IndexPath) -> String? {
        let method = methods.value[indexPath.row]
        guard let total = calculateOrderTotal(for: cart) else { return nil }
        let shippingRate = method.zoneRates.flatMap({ $0.shippingRates }).filter({ $0.isMatching == true }).first
        if let shippingRate = shippingRate {
            let shippingPrice = shippingRate.price
            let freeAbove = shippingRate.freeAbove?.centAmount ?? Int.max
            return total.centAmount > freeAbove || shippingPrice.centAmount == 0 ? NSLocalizedString("Free", comment: "Free shipping") : shippingPrice.description
        }
        return nil
    }

    // MARK: - Customer addresses retrieval

    private func retrieveShippingMethods() {
        isLoading.value = true

        Cart.active { result in
            if let cart = result.model, result.isSuccess {
                self.cart = cart
                ShippingMethod.for(cart: cart) { result in
                    if let methods = result.model, result.isSuccess {
                        self.methods.value = methods
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                }
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
        }
    }

    private func addShippingMethodToCart(at indexPath: IndexPath) {
        isLoading.value = true
        let shippingMethod = methods.value[indexPath.row]

        Cart.active { result in
            if let cart = result.model, result.isSuccess {
                let shippingMethodReference = Reference<ShippingMethod>(id: shippingMethod.id, typeId: "shipping-method")
                let updateActions = UpdateActions<CartUpdateAction>(version: cart.version, actions: [.setShippingMethod(shippingMethod: shippingMethodReference, externalTaxRate: nil)])
                Cart.update(cart.id, actions: updateActions, result: { result in
                    if result.isSuccess {
                        self.performSegueObserver.send(value: ())
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
        }
    }
}
