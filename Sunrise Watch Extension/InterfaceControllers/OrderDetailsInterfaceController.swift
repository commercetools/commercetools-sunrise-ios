//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class OrderDetailsInterfaceController: WKInterfaceController {
    
    @IBOutlet var orderNumberLabel: WKInterfaceLabel!
    @IBOutlet var shippingAddressLabel: WKInterfaceLabel!
    @IBOutlet var orderTotalLabel: WKInterfaceLabel!
    
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
        
        orderNumberLabel.setText(interfaceModel.orderNumber)
        shippingAddressLabel.setText(interfaceModel.shippingAddress)
        orderTotalLabel.setText(interfaceModel.orderTotal)
    }
}
