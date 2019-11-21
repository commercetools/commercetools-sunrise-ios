//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import UserNotifications
import Commercetools
import ReactiveSwift
import SDWebImage

class ProductDiscountNotificationController: WKUserNotificationInterfaceController {
    
    @IBOutlet var loadingImage: WKInterfaceImage!
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var productNameLabel: WKInterfaceLabel!
    @IBOutlet var productPriceLabel: WKInterfaceLabel!
    @IBOutlet var productOldPriceLabel: WKInterfaceLabel!
    
    override init() {
        if let configuration = Project.config {
            Commercetools.config = configuration
        }
        
        super.init()
    }
    
    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        if let productId = notification.request.content.userInfo["productId"] as? String {
            let query = """
                        {
                          product(id: "\(productId)") {
                            \(ReducedProduct.reducedProductQuery)
                          }
                        }
                        \(ReducedProduct.moneyFragment)
                        \(ReducedProduct.variantFragment)
                        """
            GraphQL.query(query) { (result: Commercetools.Result<GraphQLResponse<Me<ProductResponse>>>) in
                if let product = result.model?.data.me.product, result.isSuccess {
                    let interfaceModel = ReducedProductDetailsInterfaceModel(product: product)
                    DispatchQueue.main.async {
                        self.productNameLabel.setText(interfaceModel.productName)
                        let priceAttributes: [NSAttributedString.Key : Any] = [.foregroundColor: interfaceModel.productOldPrice.isEmpty ? .white : UIColor(red: 0.94, green: 0.39, blue: 0.25, alpha: 1.0)]
                        self.productPriceLabel.setAttributedText(NSAttributedString(string: interfaceModel.productPrice, attributes: priceAttributes))
                        let oldPriceAttributes: [NSAttributedString.Key : Any] = [.strikethroughStyle: 1]
                        self.productOldPriceLabel.setAttributedText(NSAttributedString(string: interfaceModel.productOldPrice, attributes: oldPriceAttributes))
                        if let url = URL(string: interfaceModel.productImageUrl) {
                            SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
                                if let image = image {
                                    self?.productImage.setImage(image)
                                }
                                self?.animate(withDuration: 0.3) {
                                    self?.loadingImage.setAlpha(0)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    self?.loadingImage.stopAnimating()
                                    self?.loadingImage.setHidden(true)
                                    self?.productImage.setHidden(false)
                                    self?.animate(withDuration: 0.3) {
                                        self?.productImage.setAlpha(1)
                                    }
                                }
                            })
                        }
                        completionHandler(.custom)
                    }
                    
                } else if let errors = result.errors as? [CTError], result.isFailure {
                    debugPrint(errors)
                }
            }
        }
    }
}
