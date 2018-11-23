//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class OrderDetailsInterfaceController: WKInterfaceController {
    
    @IBOutlet var orderStatusLabel: WKInterfaceLabel!
    @IBOutlet var orderNumberLabel: WKInterfaceLabel!
    @IBOutlet var expectedDeliveryLabel: WKInterfaceLabel!
    @IBOutlet var itemsLabel: WKInterfaceLabel!
    @IBOutlet var shippingAddressLabel: WKInterfaceLabel!
    @IBOutlet var orderTotalLabel: WKInterfaceLabel!
    @IBOutlet var lineItemsTable: WKInterfaceTable!
    
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    private var interfaceModel: OrderDetailsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        interfaceModel = context as? OrderDetailsInterfaceModel
    }
    
    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }
        
        orderStatusLabel.setAttributedText(interfaceModel.orderStatus)
        orderNumberLabel.setText(interfaceModel.orderNumber)
        expectedDeliveryLabel.setText(interfaceModel.expectedDelivery)
        itemsLabel.setText(interfaceModel.items)
        shippingAddressLabel.setText(interfaceModel.shippingAddress)
        orderTotalLabel.setText(interfaceModel.orderTotal)
        
        guard interfaceModel.numberOfLineItems > 0 else { return }
        lineItemsTable.setNumberOfRows(interfaceModel.numberOfLineItems, withRowType: LineItemRowController.identifier)
        (0...interfaceModel.numberOfLineItems - 1).forEach { row in
            if let rowController = lineItemsTable.rowController(at: row) as? LineItemRowController {
                rowController.quantityLabel.setText(interfaceModel.quantity(at: row))
                rowController.productNameLabel.setText(interfaceModel.productName(at: row))
            }
        }
        
        updateUserActivity("com.commercetools.Sunrise.viewOrderDetails", userInfo: interfaceModel.userActivityInfo, webpageURL: nil)
    }
}
