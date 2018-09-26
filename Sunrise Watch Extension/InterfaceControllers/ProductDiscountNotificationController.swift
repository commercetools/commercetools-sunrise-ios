//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import UserNotifications
import Commercetools
import ReactiveSwift
import SDWebImage

class ProductDiscountNotificationController: WKUserNotificationInterfaceController {
    
    @IBOutlet var discountInfoLabel: WKInterfaceLabel!
    @IBOutlet var productPriceLabel: WKInterfaceLabel!
    @IBOutlet var productOldPriceLabel: WKInterfaceLabel!
    @IBOutlet var productImage: WKInterfaceImage!
    
    override init() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        super.init()
    }
    
    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        if let productId = notification.request.content.userInfo["productId"] as? String {
            ProductProjection.byId(productId) { result in
                if let product = result.model, result.isSuccess {
                    let interfaceModel = ProductDetailsInterfaceModel(product: product)
                    DispatchQueue.main.async {
                        self.productPriceLabel.setText(interfaceModel.productPrice)
                        let oldPriceAttributes: [NSAttributedStringKey : Any] = [.strikethroughStyle: 1]
                        self.productOldPriceLabel.setAttributedText(NSAttributedString(string: interfaceModel.productOldPrice, attributes: oldPriceAttributes))
                        self.discountInfoLabel.setText("Price for \(interfaceModel.productName) from your wishlist just dropped from \(interfaceModel.productOldPrice) to \(interfaceModel.productPrice ?? "")!")
                        if let url = URL(string: interfaceModel.productImageUrl) {
                            SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
                                if let image = image {
                                    self?.productImage.setImage(image)
                                }
                            })
                        }
                        // TODO add discount info label text
                        completionHandler(.custom)
                    }
                    
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    debugPrint(errors)
                }
            }
        }
    }
}
