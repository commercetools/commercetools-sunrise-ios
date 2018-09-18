//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit

class ProductRowController: NSObject {

    static let identifier = "ProductRowType"

    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var wishListImage: WKInterfaceImage!
    @IBOutlet var productPrice: WKInterfaceLabel!
    @IBOutlet var productOldPrice: WKInterfaceLabel!
    @IBOutlet var productName: WKInterfaceLabel!
}
