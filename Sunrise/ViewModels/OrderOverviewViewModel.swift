//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result

class OrderOverviewViewModel: BaseViewModel {

    // Outputs
    let taxRowHidden = MutableProperty(false)
    let numberOfItems = MutableProperty("")
    let subtotal = MutableProperty("")
    let orderDiscount = MutableProperty("")
    let tax = MutableProperty("")
    let orderTotal = MutableProperty("")

    var order: MutableProperty<Order?>

    // MARK: - Lifecycle

    override init() {
        order = MutableProperty(nil)

        numberOfItems <~ order.producer.map { order in String(order?.lineItems?.count ?? 0) }

        super.init()

        subtotal <~ order.producer.map { [unowned self] _ in self.calculateSubtotal() }
        orderTotal <~ order.producer.map { [unowned self] _ in self.calculateOrderTotal() }
        tax <~ order.producer.map { [unowned self] _ in self.calculateTax() }
        taxRowHidden <~ tax.producer.map { tax in tax == "" }
        orderDiscount <~ order.producer.map { [unowned self] _ in self.calculateOrderDiscount() }

    }

    // MARK: - Data Source

    func numberOfRowsInSection(section: Int) -> Int {
        if let lineItemsCount = order.value?.lineItems?.count {
            return lineItemsCount + 1
        } else {
            return 0
        }
    }

    func lineItemNameAtIndexPath(indexPath: NSIndexPath) -> String {
        return order.value?.lineItems?[indexPath.row].name?.localizedString ?? ""
    }

    func lineItemSkuAtIndexPath(indexPath: NSIndexPath) -> String {
        return order.value?.lineItems?[indexPath.row].variant?.sku ?? ""
    }

    func lineItemSizeAtIndexPath(indexPath: NSIndexPath) -> String {
        return order.value?.lineItems?[indexPath.row].variant?.attributes?.filter({ $0.name == "size" }).first?.value as? String ?? "N/A"
    }

    func lineItemImageUrlAtIndexPath(indexPath: NSIndexPath) -> String {
        return order.value?.lineItems?[indexPath.row].variant?.images?.first?.url ?? ""
    }

    func lineItemOldPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = order.value?.lineItems?[indexPath.row].price, value = price.value,
        _ = price.discounted?.value else { return "" }

        return value.description
    }

    func lineItemPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        guard let price = order.value?.lineItems?[indexPath.row].price, value = price.value else { return "" }

        if let discounted = price.discounted?.value {
            return discounted.description
        } else {
            return value.description
        }
    }

    func lineItemQuantityAtIndexPath(indexPath: NSIndexPath) -> String {
        return order.value?.lineItems?[indexPath.row].quantity?.description ?? "0"
    }

    func lineItemTotalPriceAtIndexPath(indexPath: NSIndexPath) -> String {
        return order.value?.lineItems?[indexPath.row].totalPrice?.description ?? "N/A"
    }
    
    // MARK: - Order overview calculations
    
    func calculateOrderTotal() -> String {
        guard let order = order.value, totalPrice = order.totalPrice else { return "" }
        
        if let totalGross = order.taxedPrice?.totalGross {
            return totalGross.description
            
        } else {
            return totalPrice.description
        }
    }

    func calculateSubtotal() -> String {
        guard let lineItems = order.value?.lineItems else { return "" }
        return calculateSubtotal(lineItems)
    }

    func calculateTax() -> String {
        guard let order = order.value, totalGrossAmount = order.taxedPrice?.totalGross?.centAmount,
        totalNetAmount = order.taxedPrice?.totalNet?.centAmount else { return "" }

        return Money(currencyCode: order.lineItems?.first?.totalPrice?.currencyCode ?? "",
                centAmount: totalGrossAmount - totalNetAmount).description
    }
    
    func calculateOrderDiscount() -> String {
        guard let lineItems = order.value?.lineItems else { return "" }
        return calculateOrderDiscount(lineItems)
    }

}