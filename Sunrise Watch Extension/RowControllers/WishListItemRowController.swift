//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit

class WishListItemRowController: NSObject {

    static let identifier = "WishListItemRowType"

    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var productPrice: WKInterfaceLabel!
    @IBOutlet var productName: WKInterfaceLabel!
    @IBOutlet var addToCartButton: WKInterfaceButton!
    var moveToCartCallback: (() -> Void)?

    @IBAction func moveToCart() {
        moveToCartCallback?()
    }
}
