//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let deleteLineItemObserver: Signal<IndexPath, NoError>.Observer
    let toggleWishListObserver: Signal<IndexPath, NoError>.Observer
    var addToCartAction: Action<(String, Int), Void, CTError>!

    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfItems = MutableProperty("")
    let subtotal = MutableProperty("")
    let orderDiscount = MutableProperty("")
    let tax = MutableProperty("")
    let orderTotal = MutableProperty("")
    let isCheckoutEnabled = MutableProperty(false)
    let contentChangesSignal: Signal<Changeset, NoError>
    let performSegueSignal: Signal<String, NoError>

    let cart: MutableProperty<Cart?>

    private let contentChangesObserver: Signal<Changeset, NoError>.Observer
    private let performSegueObserver: Signal<String, NoError>.Observer
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        isLoading = MutableProperty(false)
        (performSegueSignal, performSegueObserver) = Signal<String, NoError>.pipe()
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        let (contentChangesSignal, contentChangesObserver) = Signal<Changeset, NoError>.pipe()
        self.contentChangesSignal = contentChangesSignal
        self.contentChangesObserver = contentChangesObserver

        let (deleteLineItemSignal, deleteLineItemObserver) = Signal<IndexPath, NoError>.pipe()
        self.deleteLineItemObserver = deleteLineItemObserver

        let (toggleWishListSignal, toggleWishListObserver) = Signal<IndexPath, NoError>.pipe()
        self.toggleWishListObserver = toggleWishListObserver

        cart = MutableProperty(nil)
        disposables += numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems.count ?? 0) }

        super.init()

        disposables += subtotal <~ cart.map { [unowned self] in self.calculateSubtotal(for: $0) }
        disposables += orderTotal <~ cart.map { [unowned self] in self.orderTotal(for: $0) }
        disposables += tax <~ cart.map { [unowned self] in self.calculateTax(for: $0) }
        disposables += orderDiscount <~ cart.map { [unowned self] in self.calculateOrderDiscount(for: $0) }
        disposables += isCheckoutEnabled <~ cart.map { $0?.lineItems.count ?? 0 > 0 }

        disposables += cart.signal
        .observe(on: UIScheduler())
        .observeValues {
            SunriseTabBarController.currentlyActive?.cartBadge = $0?.lineItems.count ?? 0
        }

        disposables += refreshSignal.observeValues { [weak self] in
            self?.queryForActiveCart()
        }

        disposables += deleteLineItemSignal.observeValues { [weak self] indexPath in
            self?.deleteLineItem(at: indexPath)
        }

        disposables += toggleWishListSignal
        .observeValues { [unowned self] in
            guard let lineItem = self.cart.value?.lineItems[$0.row] else { return }
            self.disposables += AppRouting.wishListViewController?.viewModel?.toggleWishListAction.apply((lineItem.productId, lineItem.variant.id))
            .startWithCompleted { [unowned self] in
                self.update(cart: self.cart.value)
            }
        }

        addToCartAction = Action(enabledIf: Property(value: true)) { [unowned self] productId, variantId -> SignalProducer<Void, CTError> in
            self.isLoading.value = true
            return self.addProduct(id: productId, variantId: variantId, quantity: 1, discountCode: nil)
        }
    }

    deinit {
        disposables.dispose()
    }

    // MARK: - Data Source

    var numberOfLineItems: Int {
        return cart.value?.lineItems.count ?? 0
    }

    func lineItemName(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].name.localizedString ?? ""
    }

    func lineItemSku(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.sku ?? ""
    }

    func lineItemSize(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].variant.attributes?.filter({ $0.name == FiltersViewModel.kSizeAttributeName }).first?.valueLabel ?? "N/A"
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
        guard let colorKey = cart.value?.lineItems[indexPath.row].variant.attributes?.filter({ $0.name == FiltersViewModel.kColorsAttributeName }).first?.valueKey else { return nil }
        return FiltersViewModel.colorValues[colorKey]
    }

    func lineItemTotalPrice(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].totalPrice.description ?? "N/A"
    }

    func isLineItemInWishList(at indexPath: IndexPath) -> Bool {
        guard let lineItem = cart.value?.lineItems[indexPath.row] else { return false }
        return AppRouting.wishListViewController?.viewModel?.lineItems.value.contains { $0.productId == lineItem.productId && $0.variantId == lineItem.variant.id } == true
    }

    func lineItemSku(at indexPath: IndexPath) -> String? {
        return cart.value?.lineItems[indexPath.row].variant.sku
    }

    func updateLineItemQuantity(at indexPath: IndexPath, quantity: String) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems[indexPath.row].id,
                let quantity = UInt(quantity) {
            self.isLoading.value = true

            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.changeLineItemQuantity(lineItemId: lineItemId, quantity: quantity),
                                                                                            .recalculate(updateProductData: nil)])
            Cart.update(cartId, actions: updateActions, expansion: discountCodesExpansion, result: { result in
                if let cart = result.model, result.isSuccess {
                    self.update(cart: cart)
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self.update(cart: nil)
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                }
                self.isLoading.value = false
            })
        }
    }

    func productDetailsViewModelForLineItem(at indexPath: IndexPath) -> ProductDetailsViewModel? {
        if let productId = cart.value?.lineItems[indexPath.row].productId {
            return ProductDetailsViewModel(productId: productId, size: lineItemSize(at: indexPath))
        }
        return nil
    }

    private func deleteLineItem(at indexPath: IndexPath) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems[indexPath.row].id {
            self.isLoading.value = true

            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.removeLineItem(lineItemId: lineItemId, quantity: nil),
                                                                                           .recalculate(updateProductData: nil)])
            Cart.update(cartId, actions: updateActions, expansion: discountCodesExpansion, result: { result in
                if let cart = result.model, result.isSuccess {
                    self.update(cart: cart)
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self.update(cart: nil)
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                }
                self.isLoading.value = false
            })
        }
    }

    // MARK: - Cart retrieval

    private func queryForActiveCart(completion: ((Cart)->())? = nil) {
        isLoading.value = true

        Cart.active(result: { result in
            if let cart = result.model, result.isSuccess {
                // Run recalculation before we present the refreshed cart
                Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: [.recalculate(updateProductData: nil)]), expansion: self.discountCodesExpansion, result: { result in
                    if let cart = result.model, result.isSuccess {
                        self.update(cart: cart)
                        completion?(cart)
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        self.update(cart: nil)
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            } else {
                // If there is no active cart, create one, with the selected product
                let cartDraft = CartDraft(currency: AppDelegate.currentCurrency ?? BaseViewModel.currencyCodeForCurrentLocale)
                Cart.create(cartDraft, expansion: self.discountCodesExpansion, result: { result in
                    if let cart = result.model, result.isSuccess {
                        self.update(cart: cart)
                        completion?(cart)
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        self.update(cart: nil)
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                    self.isLoading.value = false
                })
            }
        })
    }

    // MARK: - Calculating changeset based on old and new cart

    private func update(cart: Cart?) {
        let previousCart = self.cart.value

        var changeset = Changeset()

        if let previousCart = previousCart, let newCart = cart {
            let oldLineItems = previousCart.lineItems
            let newLineItems = newCart.lineItems

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

            var insertions = [IndexPath]()
            for (i, lineItem) in newLineItems.enumerated() {
                if !oldLineItems.contains(lineItem) {
                    insertions.append(IndexPath(row: i, section:0))
                }
            }
            changeset.insertions = insertions

        } else if let previousCart = previousCart, cart == nil && previousCart.lineItems.count > 0  {
            changeset.deletions = (0...(previousCart.lineItems.count - 1)).map { IndexPath(row: $0, section: 0) }

        } else if let lineItemsCount = cart?.lineItems.count, lineItemsCount > 0 {
            changeset.insertions = (0...lineItemsCount - 1).map { IndexPath(row: $0, section: 0) }
        }

        self.cart.value = cart
        contentChangesObserver.send(value: changeset)
    }

    // MARK: - Add product to the currently active cart

    func addProduct(id: String, variantId: Int, quantity: UInt, discountCode: String?) -> SignalProducer<Void, CTError> {
        return SignalProducer { [unowned self] observer, disposable in
            DispatchQueue.global().async {
                self.queryForActiveCart { [weak self] cart in
                    var actions = [CartUpdateAction.addLineItem(lineItemDraft: LineItemDraft(productVariantSelection: .productVariant(productId: id, variantId: variantId), quantity: quantity))]
                    if let discountCode = discountCode {
                        actions.append(.addDiscountCode(code: discountCode))
                    }
                    self?.isLoading.value = true
                    Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: actions), expansion: self?.discountCodesExpansion, result: { [weak self] result in
                        if let cart = result.model, result.isSuccess {
                            self?.update(cart: cart)
                            observer.send(value: ())

                        } else if let error = result.errors?.first as? CTError, result.isFailure {
                            observer.send(error: error)
                        }
                        self?.isLoading.value = false
                        observer.sendCompleted()
                    })
                }
            }
        }
    }

    // MARK: - Apply discount code to the currently active cart

    func add(discountCode: String) {
        queryForActiveCart { [weak self] cart in
            let actions = [CartUpdateAction.addDiscountCode(code: discountCode), .recalculate(updateProductData: nil)]
            self?.isLoading.value = true
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: actions), expansion: self?.discountCodesExpansion, result: { [weak self] result in
                if let cart = result.model, result.isSuccess {
                    self?.update(cart: cart)

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self?.alertMessageObserver.send(value: self?.alertMessage(for: errors) ?? "")
                }
                self?.isLoading.value = false
            })
        }
    }
}
