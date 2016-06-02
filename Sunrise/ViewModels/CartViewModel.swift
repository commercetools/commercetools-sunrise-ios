//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class CartViewModel: BaseViewModel {

    // Inputs
    let refreshObserver: Observer<Void, NoError>

    // Outputs
    let isLoading: MutableProperty<Bool>
    let numberOfItems: MutableProperty<String>

    let cart: MutableProperty<Cart?>

    // MARK: Lifecycle

    override init() {
        isLoading = MutableProperty(false)
        let (refreshSignal, observer) = Signal<Void, NoError>.pipe()
        refreshObserver = observer

        cart = MutableProperty(nil)
        numberOfItems = MutableProperty("")
        numberOfItems <~ cart.producer.map { cart in String(cart?.lineItems?.count ?? 0) }

        super.init()

        refreshSignal
        .observeNext { [weak self] in
            self?.queryForActiveCart()
        }
    }

    // MARK: - Data Source

    func numberOfItemsInSection(section: Int) -> Int {
        return cart.value?.lineItems?.count ?? 0
    }

    func itemNameAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].name?.localizedString ?? ""
    }

    func itemSkuAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.sku ?? ""
    }

    func itemSizeAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.attributes?.filter({ $0.name == "size" }).first?.value as? String ?? "N/A"
    }

    func itemImageUrlAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].variant?.images?.first?.url ?? ""
    }

    func itemPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].price?.value?.description ?? "N/A"
    }

    func itemTotalPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        return cart.value?.lineItems?[indexPath.row].totalPrice?.description ?? "N/A"
    }

    // MARK: - Commercetools product projections querying

    private func queryForActiveCart() {
        isLoading.value = true

        // Get the cart with state Active which has the most recent lastModifiedAt.
        Commercetools.Cart.query(predicates: ["cartState=\"Active\""], sort: ["lastModifiedAt desc"], limit: 1,
                result: { result in
                    if let results = result.response?["results"] as? [[String: AnyObject]],
                    carts = Mapper<Cart>().mapArray(results) where result.isSuccess {
                        self.cart.value = carts.first

                    } else if let errors = result.errors where result.isFailure {
                        super.alertMessageObserver.sendNext(self.alertMessageForErrors(errors))

                    }
                    self.isLoading.value = false
                })
    }



}