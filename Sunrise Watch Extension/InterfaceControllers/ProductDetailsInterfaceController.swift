//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class ProductDetailsInterfaceController: WKInterfaceController {
    
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var productPriceLabel: WKInterfaceLabel!
    @IBOutlet var productNameLabel: WKInterfaceLabel!

    private var interfaceModel: ProductDetailsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        interfaceModel = context as? ProductDetailsInterfaceModel
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        productNameLabel.setText(interfaceModel.productName)
        productPriceLabel.setText(interfaceModel.productPrice)
        if let url = URL(string: interfaceModel.productImageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
                if let image = image {
                    self?.productImage.setImage(image)
                }
            })
        }
    }
    
    @IBAction func moveToCart() {
    }
    
    @IBAction func addToWishList() {
    }
}
