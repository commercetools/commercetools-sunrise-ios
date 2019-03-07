//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Result
import Commercetools
import enum Result.Result

class CheckoutViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let pickShippingMethodObserver: Signal<IndexPath, NoError>.Observer
    let isBillingSameAsShipping = MutableProperty(true)
    let selectedShippingAddressIndexPath: MutableProperty<IndexPath?> = MutableProperty(nil)
    let selectedBillingAddressIndexPath: MutableProperty<IndexPath?> = MutableProperty(nil)
    let selectedPaymentIndexPath: MutableProperty<IndexPath?> = MutableProperty(nil)
    let discountCode: MutableProperty<String?> = MutableProperty(nil)
    let guestEmail: MutableProperty<String?> = MutableProperty(nil)
    let guestPassword: MutableProperty<String?> = MutableProperty(nil)
    let guestPasswordConfirmation: MutableProperty<String?> = MutableProperty(nil)
    var orderAction: Action<Void, Void, CTError>!

    // Outputs
    let isLoading = MutableProperty(true)
    let numberOfLineItems = MutableProperty(0)
    let subtotal = MutableProperty("")
    let shippingPrice = MutableProperty("")
    let orderDiscount = MutableProperty("")
    let tax = MutableProperty("")
    let orderTotal = MutableProperty("")
    let noActiveCartSignal: Signal<Void, NoError>
    let appliedDiscountCodeInfo = MutableProperty("")
    let isOrderValid = MutableProperty(true)

    // Dialogue texts
    let noActiveCartMessage = NSLocalizedString("Looks like there's no active cart present. Cannot proceed checkout.", comment: "No active cart checkout message")

    let cart: MutableProperty<Cart?> = MutableProperty(nil)
    let methods = MutableProperty([ShippingMethod]())
    let shippingAddresses = MutableProperty([Address]())
    let billingAddresses = MutableProperty([Address]())
    let creditCards = MutableProperty<[CreditCard]>(CreditCardStore.sharedInstance.creditCards)

    private var selectedCreditCardId = MutableProperty<String?>(CreditCardStore.sharedInstance.creditCards!.first?.id)
    private let noActiveCartObserver: Signal<Void, NoError>.Observer
    /// The serial queue used for processing cart update requests.
    private let cartUpdateQueue = DispatchQueue(label: "com.commercetools.cartUpdate")
    private let disposables = CompositeDisposable()

    // MARK: - Lifecycle

    override init() {
        (noActiveCartSignal, noActiveCartObserver) = Signal<Void, NoError>.pipe()

        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (pickShippingMethodSignal, pickShippingMethodObserver) = Signal<IndexPath, NoError>.pipe()
        self.pickShippingMethodObserver = pickShippingMethodObserver

        super.init()

        disposables += numberOfLineItems <~ cart.map { $0?.lineItems.count ?? 0 }
        disposables += subtotal <~ cart.map { [unowned self] in self.calculateSubtotal(for: $0) }
        disposables += shippingPrice <~ cart.map { [unowned self] in self.shippingPrice(for: $0) }
        disposables += orderTotal <~ cart.map { [unowned self] in self.orderTotal(for: $0) }
        disposables += tax <~ cart.map { [unowned self] in self.calculateTax(for: $0) }
        disposables += orderDiscount <~ cart.map { [unowned self] in self.calculateOrderDiscount(for: $0) }
        disposables += isBillingSameAsShipping <~ cart.map { $0?.shippingAddress?.id == $0?.billingAddress?.id }

        disposables += pickShippingMethodSignal.observeValues { [unowned self] in
            self.addShippingMethodToCart(at: $0)
        }

        disposables += shippingAddresses.producer.combineLatest(with: billingAddresses.producer).startWithValues { [unowned self] shippingAddresses, billingAddresses in
            let selectedShippingAddress = self.selectedShippingAddressIndexPath.value != nil ? shippingAddresses[self.selectedShippingAddressIndexPath.value!.item] : nil
            let selectedBillingAddress = self.selectedBillingAddressIndexPath.value != nil ? billingAddresses[self.selectedBillingAddressIndexPath.value!.item] : nil

            if let selectedShippingAddress = selectedShippingAddress, selectedShippingAddress.id != self.cart.value?.shippingAddress?.id || (self.isBillingSameAsShipping.value && self.cart.value?.billingAddress?.id != selectedShippingAddress.id) {
                self.update(address: selectedShippingAddress, type: self.isBillingSameAsShipping.value ? .both : .shipping)
            }
            if let selectedBillingAddress = selectedBillingAddress, !self.isBillingSameAsShipping.value, selectedBillingAddress.id != self.cart.value?.billingAddress?.id {
                self.update(address: selectedBillingAddress, type: .billing)
            }
        }

        disposables += selectedShippingAddressIndexPath.signal
        .skipRepeats { $0?.item == $1?.item }
        .filter { [unowned self] in $0 != nil && self.shippingAddresses.value.count > $0!.item }
        .observeValues { [unowned self] in
            let selectedShippingAddress = self.shippingAddresses.value[$0!.item]
            if self.cart.value?.shippingAddress?.id != selectedShippingAddress.id {
                self.update(address: selectedShippingAddress, type: self.isBillingSameAsShipping.value ? .both : .shipping)
            }
        }

        disposables += selectedBillingAddressIndexPath.signal
        .skipRepeats { $0?.item == $1?.item }
        .filter { [unowned self] in !self.isBillingSameAsShipping.value && $0 != nil && self.billingAddresses.value.count > $0!.item }
        .observeValues { [unowned self] in
            let selectedBillingAddress = self.billingAddresses.value[$0!.item]
            if self.cart.value?.billingAddress?.id != selectedBillingAddress.id {
                self.update(address: selectedBillingAddress, type: .billing)
            }
        }

        disposables += selectedPaymentIndexPath.signal
        .skipRepeats { $0?.item == $1?.item }
        .filter { [unowned self] in $0 != nil && self.creditCards.value.count > $0!.item }
        .observeValues { [unowned self] in
            self.selectedCreditCardId.value = self.creditCards.value[$0!.item].id
        }

        disposables += isBillingSameAsShipping.signal
        .skipRepeats()
        .observeValues { [unowned self] in
            if let selectedShippingAddress = self.cart.value?.shippingAddress, $0 {
                self.update(address: selectedShippingAddress, type: .both)
            } else if let selectedBillingAddressIndexPath = self.selectedBillingAddressIndexPath.value, !$0 {
                self.update(address: self.billingAddresses.value[selectedBillingAddressIndexPath.item], type: .billing)
            }
        }

        disposables += discountCode.signal
        .filter { $0?.count ?? 0 > 0 }
        .observeValues { [unowned self] in
            self.apply(discountCode: $0!)
        }

        disposables += isOrderValid <~ SignalProducer.combineLatest(guestEmail.producer, guestPassword.producer,
                guestPasswordConfirmation.producer, cart.producer).map { [unowned self] in let (guestEmail, guestPassword, guestPasswordConfirmation, cart) = $0
            if self.isAuthenticated {
                return cart?.shippingInfo != nil
            } else {
                return cart?.shippingInfo != nil && guestEmail?.isEmpty == false && (guestPassword?.isEmpty == true || (guestPassword?.isEmpty == false && guestPassword == guestPasswordConfirmation))
            }
        }

        orderAction = Action(enabledIf: isOrderValid) { [unowned self] _ in
            self.isLoading.value = true
            return self.makeOrder()
        }

        refreshSignal.observeValues { [unowned self] in
            self.selectedShippingAddressIndexPath.value = nil
            self.selectedBillingAddressIndexPath.value = nil
            self.shippingAddresses.value = []
            self.billingAddresses.value = []
            self.creditCards.value = CreditCardStore.sharedInstance.creditCards
            self.queryForActiveCart()
        }
    }

    deinit {
        disposables.dispose()
    }

    func addressViewModelForAddress(at indexPath: IndexPath, type: AddressType) -> AddressViewModel {
        let address = type == .shipping ? shippingAddresses.value[indexPath.item] : billingAddresses.value[indexPath.item]
        return AddressViewModel(address: address, type: type)
    }

    func paymentViewModelForPayment(at indexPath: IndexPath) -> PaymentViewModel {
        return PaymentViewModel(creditCard: creditCards.value[indexPath.item])
    }

    // MARK: - Line Items Data Source

    func lineItemName(at indexPath: IndexPath) -> String {
        return cart.value?.lineItems[indexPath.row].name.localizedString ?? ""
    }

    func lineItemQuantity(at indexPath: IndexPath) -> String {
        return "x\(cart.value?.lineItems[indexPath.row].quantity ?? 0)"
    }

    func lineItemPrice(at indexPath: IndexPath) -> String {
        guard let lineItem = cart.value?.lineItems[indexPath.row] else { return "" }

        return price(for: lineItem)
    }

    // MARK: - Shipping Methods Data Source

    func shippingMethodName(at indexPath: IndexPath) -> String? {
        return methods.value[indexPath.row].name
    }

    func shippingMethodDescription(at indexPath: IndexPath) -> String? {
        return methods.value[indexPath.row].description
    }

    func shippingMethodPrice(at indexPath: IndexPath) -> String? {
        let method = methods.value[indexPath.row]
        guard let cart = cart.value, let total = calculateOrderTotal(for: cart) else { return nil }
        let shippingRate = method.zoneRates.flatMap({ $0.shippingRates }).filter({ $0.isMatching == true }).first
        if let shippingRate = shippingRate {
            let shippingPrice = shippingRate.price
            let freeAbove = shippingRate.freeAbove?.centAmount ?? Int.max
            return total.centAmount > freeAbove || shippingPrice.centAmount == 0 ? NSLocalizedString("Free", comment: "Free shipping") : shippingPrice.description
        }
        return nil
    }

    func isShippingMethodSelected(at indexPath: IndexPath) -> Bool {
        return cart.value?.shippingInfo?.shippingMethod?.id == methods.value[indexPath.row].id
    }

    // MARK: - Shipping Addresses Data Sources

    func addressName(at indexPath: IndexPath, for type: AddressType) -> String? {
        let address = type == .shipping ? shippingAddresses.value[indexPath.item] : billingAddresses.value[indexPath.item]
        var name = ""
        name += address.title != nil ? "\(address.title!) " : ""
        name += address.firstName != nil ? "\(address.firstName!) " : ""
        name += address.lastName ?? ""
        return name
    }

    func addressDetails(at indexPath: IndexPath, for type: AddressType) -> String? {
        let address = type == .shipping ? shippingAddresses.value[indexPath.item] : billingAddresses.value[indexPath.item]
        return address.description
    }

    func isAddressSelected(at indexPath: IndexPath, for type: AddressType) -> Bool {
        let address = type == .shipping ? shippingAddresses.value[indexPath.item] : billingAddresses.value[indexPath.item]
        return type == .shipping ? cart.value?.shippingAddress?.id == address.id : cart.value?.billingAddress?.id == address.id
    }

    // MARK: - Payments Data Source

    func cardLast4Digits(at indexPath: IndexPath) -> String? {
        let fullNumber = creditCards.value[indexPath.item].number
        guard fullNumber.count >= 4 else { return nil }
        return String(fullNumber.suffix(from: fullNumber.index(fullNumber.endIndex, offsetBy: -4)))
    }

    func cardName(at indexPath: IndexPath) -> String {
        return creditCards.value[indexPath.item].name
    }

    // MARK: - Cart management

    private func queryForActiveCart() {
        isLoading.value = true

        activeCart { activeCart in
            if let activeCart = activeCart {
                self.cart.value = activeCart
                self.retrieveShippingMethods()
            }
        }
    }

    private func activeCart(completion: @escaping (Cart?) -> Void) {
        Cart.active { result in
            if result.isFailure, result.statusCode == 404 {
                self.noActiveCartObserver.send(value: ())
                self.isLoading.value = false
            } else if let errors = result.errors as? [CTError], result.isFailure {
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                self.isLoading.value = false
            }
            completion(result.model)
        }
    }

    private func updateActiveCart(actions: [CartUpdateAction], completion: ((Cart?) -> Void)? = nil) {
        cartUpdateQueue.async { [unowned self] in
            let semaphore = DispatchSemaphore(value: 0)
            self.activeCart { activeCart in
                if let cart = activeCart {
                    Cart.update(cart.id, actions: UpdateActions<CartUpdateAction>(version: cart.version, actions: actions), expansion: self.discountCodesExpansion) { result in
                        if let cart = result.model, result.isSuccess {
                            self.cart.value = cart
                        } else if let errors = result.errors as? [CTError], result.isFailure {
                            self.alertMessageObserver.send(value: self.alertMessage(for: errors))
                        }
                        self.isLoading.value = false
                        completion?(result.model)
                        semaphore.signal()
                    }
                } else {
                    semaphore.signal()
                }
            }
            _ = semaphore.wait(timeout: .distantFuture)
        }
    }

    // MARK: - Retrieving and setting shipping method

    private func retrieveShippingMethods() {
        guard let cart = cart.value else { return }
        let shippingMethodResultHandler: ((Commercetools.Result<ShippingMethods>) -> Void) = { [weak self] result in
            if let methods = result.model, result.isSuccess {
                self?.methods.value = methods
                self?.retrieveCustomerAddresses()
            } else if let errors = result.errors as? [CTError], result.isFailure, let alertMessage = self?.alertMessage(for: errors) {
                self?.alertMessageObserver.send(value: alertMessage)
                self?.isLoading.value = false
            }
        }
        if cart.shippingAddress != nil {
            ShippingMethod.for(cart: cart, result: shippingMethodResultHandler)
        } else if let country = Customer.currentCountry {
            ShippingMethod.for(country: country, result: shippingMethodResultHandler)
        }
    }

    private func addShippingMethodToCart(at indexPath: IndexPath) {
        isLoading.value = true
        let shippingMethod = methods.value[indexPath.row]

        let shippingMethodReference = ResourceIdentifier(id: shippingMethod.id, typeId: .shippingMethod)
        updateActiveCart(actions: [.setShippingMethod(shippingMethod: shippingMethodReference), .recalculate(updateProductData: nil)])
    }

    // MARK: - Retrieving customer addresses

    private func retrieveCustomerAddresses() {
        guard shippingAddresses.value.isEmpty, billingAddresses.value.isEmpty else {
            isLoading.value = false
            return
        }
        selectedShippingAddressIndexPath.value = nil
        selectedBillingAddressIndexPath.value = nil

        if !isAuthenticated {
            if let shippingAddress = cart.value?.shippingAddress {
                shippingAddresses.value = [shippingAddress]
            }
            if let billingAddress = cart.value?.billingAddress {
                billingAddresses.value = [billingAddress]
            }
            setShippingAndBillingIfEmpty()
            isLoading.value = false
        } else {
            Customer.profile { result in
                if let customer = result.model, result.isSuccess {
                    var shippingAddresses = customer.addresses.filter({ customer.billingAddressIds?.contains($0.id ?? "") == false })
                    if let defaultShippingAddressId = customer.defaultShippingAddressId, let defaultShippingAddress = customer.addresses.first(where: { $0.id == defaultShippingAddressId }), let index = shippingAddresses.index(where: { $0.id == defaultShippingAddressId }) {
                        shippingAddresses.remove(at: index)
                        shippingAddresses.insert(defaultShippingAddress, at: 0)
                    }

                    var billingAddresses = customer.addresses.filter({ customer.shippingAddressIds?.contains($0.id ?? "") == false })
                    if let defaultBillingAddressId = customer.defaultBillingAddressId, let defaultBillingAddress = customer.addresses.first(where: { $0.id == defaultBillingAddressId }), let index = billingAddresses.index(where: { $0.id == defaultBillingAddressId }) {
                        billingAddresses.remove(at: index)
                        billingAddresses.insert(defaultBillingAddress, at: 0)
                    }

                    if let shippingAddress = self.cart.value?.shippingAddress {
                        if let index = shippingAddresses.index(where: { $0.id == shippingAddress.id }) {
                            shippingAddresses.remove(at: index)
                        }
                        shippingAddresses.insert(shippingAddress, at: 0)
                    }

                    if let billingAddress = self.cart.value?.billingAddress {
                        if let index = billingAddresses.index(where: { $0.id == billingAddress.id }) {
                            billingAddresses.remove(at: index)
                        }
                        billingAddresses.insert(billingAddress, at: 0)
                    }

                    self.shippingAddresses.value = shippingAddresses
                    self.billingAddresses.value = billingAddresses

                    self.setShippingAndBillingIfEmpty()

                } else if let errors = result.errors as? [CTError], result.isFailure {
                    super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                }
                self.isLoading.value = false
            }
        }
    }

    private func setShippingAndBillingIfEmpty() {
        guard let cart = cart.value, selectedShippingAddressIndexPath.value == nil, selectedBillingAddressIndexPath.value == nil else { return }
        if cart.shippingAddress == nil, shippingAddresses.value.count > 0 {
            update(address: shippingAddresses.value[0], type: isBillingSameAsShipping.value ? .both : .shipping)
        }
        if cart.billingAddress == nil, billingAddresses.value.count > 0, !isBillingSameAsShipping.value {
            update(address: billingAddresses.value[0], type: .billing)
        }
    }

    // MARK: - Updating cart shipping and billing addresses

    private func update(address: Address, type: AddressType) {
        isLoading.value = true
        var actions = [CartUpdateAction]()
        switch type {
            case .shipping:
                actions.append(.setShippingAddress(address: address))
            case .billing:
                actions.append(.setBillingAddress(address: address))
            case .both:
                actions += [.setShippingAddress(address: address), .setBillingAddress(address: address)]
            }
        actions.append(.recalculate(updateProductData: nil))
        updateActiveCart(actions: actions) { updatedCart in
            if updatedCart != nil {
                self.retrieveShippingMethods()
            }
        }
    }

    // MARK: - Apply discount code to the currently active cart

    private func apply(discountCode: String) {
        isLoading.value = true
        updateActiveCart(actions: [.addDiscountCode(code: discountCode), .recalculate(updateProductData: nil)]) { updatedCart in
            if let cart = updatedCart {
                if let appliedDiscountCodeInfo = cart.discountCodes.first(where: { $0.discountCode.obj?.code == discountCode }), let appliedDiscountCode = appliedDiscountCodeInfo.discountCode.obj {
                    self.appliedDiscountCodeInfo.value = "\(appliedDiscountCode.name?.localizedString ?? "") \(appliedDiscountCode.description?.localizedString ?? "")"
                }
            }
        }
    }

    // MARK: - Submitting Order

    private func makeOrder() -> SignalProducer<Void, CTError> {
        return SignalProducer { [unowned self] observer, disposable in
            DispatchQueue.global().async {
                self.setCustomerEmail()
                if !self.isAuthenticated, self.guestPassword.value?.isEmpty == false {
                    let signUpResult = self.signUp()
                    if case let .failure(error)? = signUpResult {
                        observer.send(error: error)
                        observer.sendCompleted()
                        return
                    }
                }
                self.activeCart { activeCart in
                    if let cart = activeCart {
                        let orderDraft = OrderDraft(id: cart.id, version: cart.version)
                        Order.create(orderDraft) { result in
                            if result.isSuccess {
                                self.addToAddressBook(from: cart)
                                observer.send(value: ())
                            } else if let error = result.errors?.first as? CTError, result.isFailure {
                                self.isLoading.value = false
                                observer.send(error: error)
                            }
                            observer.sendCompleted()
                        }
                    } else {
                        observer.sendCompleted()
                    }
                }
            }
        }
    }

    private func setCustomerEmail() {
        guard !isAuthenticated else { return }
        let semaphore = DispatchSemaphore(value: 0)
        updateActiveCart(actions: [.setCustomerEmail(email: self.guestEmail.value)]) { _ in
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }

    private func signUp() -> Result<Void, CTError>? {
        guard let email = guestEmail.value, let password = guestPassword.value else { return nil }
        var error: CTError? = nil
        let semaphore = DispatchSemaphore(value: 0)
        let draft = CustomerDraft(email: email, password: password)
        Commercetools.signUpCustomer(draft) { result in
            if result.isSuccess {
                Commercetools.loginCustomer(username: email, password: password, activeCartSignInMode: .useAsNewActiveCustomerCart) { result in
                    AppDelegate.saveDeviceTokenForCurrentCustomer()
                    error = result.errors?.first as? CTError
                    semaphore.signal()
                }
            } else {
                error = result.errors?.first as? CTError
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .distantFuture)
        return error != nil ? Result<Void, CTError>.failure(error!) : .success(())
    }

    private func addToAddressBook(from cart: Cart) {
        guard isAuthenticated else { return }
        var addressesToAdd = [Address]()
        if let shippingAddress = cart.shippingAddress, shippingAddress.id == nil {
            addressesToAdd.append(shippingAddress)
        }
        if let billingAddress = cart.billingAddress, billingAddress.id == nil {
            addressesToAdd.append(billingAddress)
        }
        guard addressesToAdd.count > 0 else { return }
        let semaphore = DispatchSemaphore(value: 0)
        Customer.profile { result in
            if let profile = result.model, result.isSuccess {
                let updateActions = UpdateActions(version: profile.version, actions: addressesToAdd.map { CustomerUpdateAction.addAddress(address: $0) })
                Customer.update(actions: updateActions) { _ in
                    semaphore.signal()
                }
            } else {
                semaphore.signal()
            }
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }

    enum AddressType {
        case shipping
        case billing
        case both
    }
}
