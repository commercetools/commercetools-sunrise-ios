//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class ProductDetailsInterfaceController: WKInterfaceController {
    
    @IBOutlet var productImageGroup: WKInterfaceGroup!
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var loadingImage: WKInterfaceImage!
    @IBOutlet var wishListButton: WKInterfaceButton!
    @IBOutlet var productPriceLabel: WKInterfaceLabel!
    @IBOutlet var productOldPriceLabel: WKInterfaceLabel!
    @IBOutlet var productNameLabel: WKInterfaceLabel!
    @IBOutlet var moveToCartButton: WKInterfaceButton!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    private var interfaceModel: ProductDetailsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        interfaceModel = context as? ProductDetailsInterfaceModel
        let screenHeight = WKInterfaceDevice.current().screenBounds.height
        productImageGroup.setHeight(screenHeight * 0.7)
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        productNameLabel.setText(interfaceModel.productName)
        let priceAttributes: [NSAttributedString.Key : Any] = [.foregroundColor: interfaceModel.productOldPrice.isEmpty ? .white : UIColor(red: 0.94, green: 0.39, blue: 0.25, alpha: 1.0)]
        productPriceLabel?.setAttributedText(NSAttributedString(string: interfaceModel.productPrice, attributes: priceAttributes))
        let oldPriceAttributes: [NSAttributedString.Key : Any] = [.strikethroughStyle: 1]
        productOldPriceLabel.setAttributedText(NSAttributedString(string: interfaceModel.productOldPrice, attributes: oldPriceAttributes))
        if let url = URL(string: interfaceModel.productImageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
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

        disposables += interfaceModel.moveToCartAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            switch event {
                case .value(_):
                    self?.presentAlert(withTitle: NSLocalizedString("Added to cart", comment: "Added to cart"), message: NSLocalizedString("Product has been added to cart", comment: "Added to cart message"), preferredStyle: .alert, actions: [WKAlertAction.okAction])
                case let .failed(error):
                    self?.presentAlert(withTitle: NSLocalizedString("Could not add to cart", comment: "Could not add to cart"), message: error.errorDescription, preferredStyle: .alert, actions: [WKAlertAction.okAction])
                case .completed:
                    self?.moveToCartButton.setEnabled(true)
                default:
                    return
            }
        }

        updateUserActivity("com.commercetools.Sunrise.viewProductDetails", userInfo: interfaceModel.userActivityInfo, webpageURL: nil)
    }

    @IBAction func moveToCart() {
        moveToCartButton.setEnabled(false)
        disposables += interfaceModel?.moveToCartAction.apply().start()
    }
    
    @IBAction func toggleWishList() {
        guard interfaceModel?.isWishListButtonEnabled.value == true else { return }
        wishListButton.setBackgroundImageNamed(interfaceModel?.isInWishList.value == false ? "wishlist_icon_active" : "wishlist_icon")
        interfaceModel?.toggleWishListObserver.send(value: ())
    }
}

extension WKAlertAction {
    static var okAction: WKAlertAction {
        return WKAlertAction(title: "OK", style: .default, handler: {})
    }
}
