//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import PassKit

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let deleteLineItemObserver: Signal<IndexPath, NoError>.Observer
    let toggleWishListObserver: Signal<IndexPath, NoError>.Observer
    var addToCartAction: Action<(String, Int), Void, CTError>!
    var applePayAction: Action<Void, Void, NoError>!

    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfItems = MutableProperty("")
    let orderTotal = MutableProperty("")
    let isCheckoutEnabled = MutableProperty(false)
    let shouldPresentOrderConfirmation = MutableProperty(false)
    let presentAuthorizationSignal: Signal<PKPaymentRequest, NoError>
    let contentChangesSignal: Signal<Changeset, NoError>
    let performSegueSignal: Signal<String, NoError>

    let cart: MutableProperty<Cart?>

    private let contentChangesObserver: Signal<Changeset, NoError>.Observer
    private let performSegueObserver: Signal<String, NoError>.Observer
    private var shippingAddress: Address? // Used for Apple Pay checkout, for authenticated customers
    private var billingAddress: Address? // Used for Apple Pay checkout, for authenticated customers
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

        let (presentAuthorizationSignal, presentAuthorizationObserver) = Signal<PKPaymentRequest, NoError>.pipe()
        self.presentAuthorizationSignal = presentAuthorizationSignal

        cart = MutableProperty(nil)
        disposables += numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems.count ?? 0) }

        super.init()

        disposables += orderTotal <~ cart.map { [unowned self] in self.orderTotal(for: $0) }
        disposables += isCheckoutEnabled <~ cart.map { $0?.lineItems.count ?? 0 > 0 }

        disposables += cart.signal
        .observe(on: UIScheduler())
        .observeValues {
            SunriseTabBarController.currentlyActive?.cartBadge = $0?.lineItems.count ?? 0
        }

        disposables += refreshSignal.observeValues { [weak self] in
            self?.queryForActiveCart()
            self?.retrieveShippingAndBillingAddresses()
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

        applePayAction = Action(enabledIf: Property(value: true)) { SignalProducer.empty }

        disposables += applePayAction.completed
        .observe(on: QueueScheduler(qos: .userInteractive))
        .observeValues { [unowned self] in
            self.isLoading.value = true
            guard let request = self.paymentRequest else { return }
            self.isLoading.value = false
            presentAuthorizationObserver.send(value: request)
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: .UIApplicationDidBecomeActive)
        .observeValues { [unowned self] _ in
            self.refreshObserver.send(value: ())
        }
    }

    deinit {
        disposables.dispose()
    }

    static var recommendationsViewModel: InlineProductOverviewViewModel? {
        return InlineProductOverviewViewModel(title: NSLocalizedString("Recommended for you", comment: "Recommended for you"), useMyStyleSettings: true)
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
            Cart.update(cartId, actions: updateActions, expansion: shippingMethodExpansion, result: { result in
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
        if let lineItem = cart.value?.lineItems[indexPath.row] {
            return ProductDetailsViewModel(productId: lineItem.productId, variantId: lineItem.variant.id)
        }
        return nil
    }

    private func deleteLineItem(at indexPath: IndexPath) {
        if let cartId = cart.value?.id, let version = cart.value?.version, let lineItemId = cart.value?.lineItems[indexPath.row].id {
            self.isLoading.value = true

            let updateActions = UpdateActions<CartUpdateAction>(version: version, actions: [.removeLineItem(lineItemId: lineItemId, quantity: nil, shippingDetailsToRemove: nil),
                                                                                            .recalculate(updateProductData: nil)])
            Cart.update(cartId, actions: updateActions, expansion: shippingMethodExpansion, result: { result in
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
                Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: [.recalculate(updateProductData: nil)]), expansion: self.shippingMethodExpansion, result: { result in
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
                let cartDraft = CartDraft(currency: Customer.currentCurrency ?? Locale.currencyCodeForCurrentLocale)
                Cart.create(cartDraft, expansion: self.shippingMethodExpansion, result: { result in
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
            changeset.modifications = modifications

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
                self.queryForActiveCart { [unowned self] cart in
                    var actions = [CartUpdateAction.addLineItem(lineItemDraft: LineItemDraft(productVariantSelection: .productVariant(productId: id, variantId: variantId), quantity: quantity))]
                    if let discountCode = discountCode {
                        actions.append(.addDiscountCode(code: discountCode))
                    }
                    self.isLoading.value = true
                    Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: actions), expansion: self.shippingMethodExpansion, result: { [weak self] result in
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
        queryForActiveCart { [unowned self] cart in
            let actions = [CartUpdateAction.addDiscountCode(code: discountCode), .recalculate(updateProductData: nil)]
            self.isLoading.value = true
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: actions), expansion: self.shippingMethodExpansion, result: { [weak self] result in
                if let cart = result.model, result.isSuccess {
                    self?.update(cart: cart)

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    self?.alertMessageObserver.send(value: self?.alertMessage(for: errors) ?? "")
                }
                self?.isLoading.value = false
            })
        }
    }

    // MARK: - Retrieve shipping and billing addresses for authenticated customers for Apple Pay checkout

    func retrieveShippingAndBillingAddresses() {
        if isAuthenticated {
            Customer.profile { result in
                guard let profile = result.model else { return }
                self.shippingAddress = profile.addresses.first(where: { $0.id == profile.defaultShippingAddressId }) ?? profile.addresses.first
                self.billingAddress = profile.addresses.first(where: { $0.id == profile.defaultBillingAddressId }) ?? profile.addresses.first
                // For convenience, if email is not set for shipping or billing address, prepopulate it with email from profile
                if self.shippingAddress?.email == nil {
                    self.shippingAddress?.email = profile.email
                }
                if self.billingAddress?.email == nil {
                    self.billingAddress?.email = profile.email
                }
            }
        } else {
            shippingAddress = nil
            billingAddress = nil
        }
    }

    // MARK: - Apple Pay checkout

    func createOrder(with payment: PKPayment, completion: @escaping (PKPaymentAuthorizationResult) -> Swift.Void) {
        guard let cart = cart.value else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
            return
        }
        let methodInfo = PaymentMethodInfo(paymentInterface: "ApplePay", method: payment.token.paymentMethod.displayName, name: nil)
        let paymentDraft = PaymentDraft(amountPlanned: cart.taxedPrice?.totalGross ?? cart.totalPrice, paymentMethodInfo: methodInfo, custom: nil, transaction: TransactionDraft(type: .authorization, amount: cart.taxedPrice?.totalGross ?? cart.totalPrice, interactionId: payment.token.transactionIdentifier))
        Payment.create(paymentDraft) { result in
            if let ctPayment = result.model, result.isSuccess {
                var actions = [CartUpdateAction]()
                if let activeShippingMethodId = payment.shippingMethod?.identifier {
                    let shippingMethodReference = Reference<ShippingMethod>(id: activeShippingMethodId, typeId: "shipping-method")
                    actions.append(.setShippingMethod(shippingMethod: shippingMethodReference))
                }
                actions.append(.setShippingAddress(address: payment.shippingContact?.ctAddress))
                actions.append(.setBillingAddress(address: payment.billingContact?.ctAddress))
                let paymentReference = Reference<Payment>(id: ctPayment.id, typeId: "payment")
                actions.append(.addPayment(payment: paymentReference))

                Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: actions), expansion: self.shippingMethodExpansion) { result in
                    if let cart = result.model, result.isSuccess {
                        Order.create(OrderDraft(id: cart.id, version: cart.version)) {  result in
                            self.shouldPresentOrderConfirmation.value = true
                            result.isSuccess ? completion(PKPaymentAuthorizationResult(status: .success, errors: [])) : completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                        }
                    } else {
                        completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                    }
                }
            } else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
            }
        }
    }

    func update(shippingAddress: PKContact, completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Swift.Void) {
        queryForActiveCart { cart in
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: [.setShippingAddress(address: shippingAddress.ctAddress), .recalculate(updateProductData: nil)]), expansion: self.shippingMethodExpansion) { result in
                if let updatedCart = result.model, result.isSuccess {
                    self.cart.value = updatedCart
                    self.shippingMethods { methods, errors in
                        if !methods.isEmpty {
                            completion(PKPaymentRequestShippingContactUpdate(errors: nil, paymentSummaryItems: self.paymentSummaryItems, shippingMethods: methods))
                        } else {
                            completion(PKPaymentRequestShippingContactUpdate(errors: errors, paymentSummaryItems: [], shippingMethods: []))
                        }
                    }
                } else {
                    completion(PKPaymentRequestShippingContactUpdate(errors: [NSError(domain: PKPassKitError.errorDomain, code: PKPassKitError.unknownError.rawValue)], paymentSummaryItems: [], shippingMethods: []))
                }
            }
        }
    }

    func select(shippingMethod: PKShippingMethod, completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Swift.Void) {
        guard let cart = cart.value else {
            completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: []))
            return
        }
        if let activeShippingMethodId = shippingMethod.identifier {
            let shippingMethodReference = Reference<ShippingMethod>(id: activeShippingMethodId, typeId: "shipping-method")
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: [.setShippingMethod(shippingMethod: shippingMethodReference)]), expansion: shippingMethodExpansion) { result in
                if let cart = result.model {
                    self.cart.value = cart
                    completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: self.paymentSummaryItems))
                } else {
                    completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: []))
                }
            }
        } else {
            completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: paymentSummaryItems))
        }
    }

    private var paymentRequest: PKPaymentRequest? {
        guard var cart = cart.value, let countryCode = Customer.currentCountry else { return nil }
        let request = PKPaymentRequest()
        request.countryCode = countryCode
        request.currencyCode = cart.totalPrice.currencyCode
        request.supportedNetworks = PKPaymentRequest.availableNetworks()
        request.merchantCapabilities = [.capabilityDebit, .capabilityCredit, .capability3DS, .capabilityEMV]
        request.merchantIdentifier = ""
        request.requiredShippingContactFields = [.name, .emailAddress, .postalAddress]
        request.requiredBillingContactFields = [.name, .emailAddress, .postalAddress]
        let semaphore = DispatchSemaphore(value: 0)
        if let shippingAddress = shippingAddress {
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: [.setShippingAddress(address: shippingAddress), .recalculate(updateProductData: nil)]), expansion: shippingMethodExpansion) { result in
                if let updatedCart = result.model, result.isSuccess {
                    self.cart.value = updatedCart
                    cart = updatedCart
                    request.shippingContact = shippingAddress.pkContact
                    self.shippingMethods { shippingMethods, _ in
                        request.shippingMethods = shippingMethods
                        semaphore.signal()
                    }
                } else {
                    semaphore.signal()
                }
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
        if let billingAddress = billingAddress {
            Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: [.setBillingAddress(address: billingAddress), .recalculate(updateProductData: nil)]), expansion: shippingMethodExpansion) { result in
                if let updatedCart = result.model, result.isSuccess {
                    self.cart.value = updatedCart
                    cart = updatedCart
                    request.billingContact = billingAddress.pkContact
                }
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
        request.paymentSummaryItems = paymentSummaryItems

        return request
    }

    private func shippingMethods(completion: @escaping ([PKShippingMethod], [Error]) -> Swift.Void) {
        guard let cart = cart.value else {
            completion([], [NSError(domain: PKPassKitError.errorDomain, code: PKPassKitError.unknownError.rawValue)])
            return
        }
        ShippingMethod.for(cart: cart) { result in
            var shippingMethods: [PKShippingMethod] = result.model?.map {
                var amount = NSDecimalNumber(value: 0)
                if let matchingPrice = $0.matchingPrice(for: cart.taxedPrice?.totalGross.centAmount ?? cart.totalPrice.centAmount) {
                    amount = NSDecimalNumber(value: Double(matchingPrice.centAmount) / 100)
                }
                let method = PKShippingMethod(label: $0.name, amount: amount)
                method.identifier = $0.id
                method.detail = $0.description
                return method
            } ?? []
            if let activeShippingMethodId = cart.shippingInfo?.shippingMethod?.id, let index = shippingMethods.index(where: { $0.identifier == activeShippingMethodId }) {
                let activeMethod = shippingMethods.remove(at: index)
                shippingMethods.insert(activeMethod, at: 0)
                completion(shippingMethods, [])
            } else if let activeShippingMethodId = shippingMethods.first?.identifier {
                let shippingMethodReference = Reference<ShippingMethod>(id: activeShippingMethodId, typeId: "shipping-method")
                Cart.update(cart.id, actions: UpdateActions(version: cart.version, actions: [.setShippingMethod(shippingMethod: shippingMethodReference)]), expansion: self.shippingMethodExpansion) { result in
                    if let cart = result.model, result.isSuccess {
                        self.cart.value = cart
                        completion(shippingMethods, [])
                    } else {
                        completion([], [NSError(domain: PKPassKitError.errorDomain, code: PKPassKitError.unknownError.rawValue)])
                    }
                }
            } else {
                completion(shippingMethods, [])
            }
        }
    }

    private var paymentSummaryItems: [PKPaymentSummaryItem] {
        guard let cart = cart.value else { return [] }
        var items = cart.lineItems.map { lineItem -> PKPaymentSummaryItem in
            let priceCentAmount = lineItem.price.discounted?.value.centAmount ?? lineItem.discountedPricePerQuantity.first?.discountedPrice.value.centAmount ?? lineItem.price.value.centAmount
            let amount = Double(priceCentAmount) / 100.0
            return PKPaymentSummaryItem(label: lineItem.name.localizedString ?? "", amount: NSDecimalNumber(value: amount))
        }
        if let shippingMethod = cart.shippingInfo?.shippingMethod?.obj, let centAmount = cart.shippingInfo?.price.centAmount {
            let method = PKShippingMethod(label: shippingMethod.name, amount: NSDecimalNumber(value: Double(centAmount) / 100))
            method.identifier = shippingMethod.id
            method.detail = shippingMethod.description
            items.append(method)
        }
        let totalAmount = Double((cart.taxedPrice?.totalGross ?? cart.totalPrice).centAmount) / 100.0
        items.append(PKPaymentSummaryItem(label: NSLocalizedString("Total", comment: "Total"), amount: NSDecimalNumber(value: totalAmount)))
        return items
    }
}
