//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit

class OrderItemRowController: NSObject {
    
    @IBOutlet var itemsLabel: WKInterfaceLabel!
    @IBOutlet var orderStatusLabel: WKInterfaceLabel!
    @IBOutlet var orderDescriptionLabel: WKInterfaceLabel!
    @IBOutlet var orderTotalLabel: WKInterfaceLabel!
    static let identifier = "OrderItemRowType"
}
