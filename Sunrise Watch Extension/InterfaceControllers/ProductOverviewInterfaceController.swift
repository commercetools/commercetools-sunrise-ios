//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class ProductOverviewInterfaceController: WKInterfaceController {
    
    @IBOutlet var productButton: WKInterfaceButton!
    @IBOutlet var wishListButton: WKInterfaceButton!
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var loadingImage: WKInterfaceImage!
    @IBOutlet var productPriceLabel: WKInterfaceLabel?
    @IBOutlet var productOldPriceLabel: WKInterfaceLabel?
    @IBOutlet var productNameLabel: WKInterfaceLabel?
    
    private let disposables = CompositeDisposable()

    private var interfaceModel: ProductDetailsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }
    
    deinit {
        disposables.dispose()
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        interfaceModel = context as? ProductDetailsInterfaceModel
    }

    override func contextForSegue(withIdentifier segueIdentifier: String) -> Any? {
        return interfaceModel
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }
        
        let priceAttributes: [NSAttributedString.Key : Any] = [.foregroundColor: interfaceModel.productOldPrice.isEmpty ? .black : UIColor(red: 0.94, green: 0.39, blue: 0.25, alpha: 1.0)]
        productPriceLabel?.setAttributedText(NSAttributedString(string: interfaceModel.productPrice, attributes: priceAttributes))
        let oldPriceAttributes: [NSAttributedString.Key : Any] = [.strikethroughStyle: 1]
        productOldPriceLabel?.setAttributedText(NSAttributedString(string: interfaceModel.productOldPrice, attributes: oldPriceAttributes))
        productNameLabel?.setText(interfaceModel.productName)
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
        
        disposables += interfaceModel.isInWishList.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in
            self?.wishListButton.setBackgroundImageNamed($0 ? "wishlist_icon_active" : "wishlist_icon")
        }
    }
    
    @IBAction func toggleWishList() {
        guard interfaceModel?.isWishListButtonEnabled.value == true else { return }
        wishListButton.setBackgroundImageNamed(interfaceModel?.isInWishList.value == false ? "wishlist_icon_active" : "wishlist_icon")
        interfaceModel?.toggleWishListObserver.send(value: ())
    }
}
