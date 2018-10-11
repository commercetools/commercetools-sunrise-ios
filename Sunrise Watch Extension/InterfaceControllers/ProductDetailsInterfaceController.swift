//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class ProductDetailsInterfaceController: WKInterfaceController {
    
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var productPriceLabel: WKInterfaceLabel!
    @IBOutlet var productOldPriceLabel: WKInterfaceLabel!
    @IBOutlet var productNameLabel: WKInterfaceLabel!
    @IBOutlet var moveToCartButton: WKInterfaceButton!
    @IBOutlet var wishListButton: WKInterfaceButton!

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
    }
    
    override func willDisappear() {
        invalidateUserActivity()
        super.willDisappear()
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        productNameLabel.setText(interfaceModel.productName)
        productPriceLabel.setText(interfaceModel.productPrice)
        let oldPriceAttributes: [NSAttributedStringKey : Any] = [.strikethroughStyle: 1]
        productOldPriceLabel.setAttributedText(NSAttributedString(string: interfaceModel.productOldPrice, attributes: oldPriceAttributes))
        if let url = URL(string: interfaceModel.productImageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
                if let image = image {
                    self?.productImage.setImage(image)
                }
            })
        }

        disposables += interfaceModel.moveToCartAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            switch event {
                case .value(_):
                    self?.presentAlert(withTitle: "Moved to cart", message: "Product has been moved to cart", preferredStyle: .alert, actions: [WKAlertAction.okAction])
                case let .failed(error):
                    self?.presentAlert(withTitle: "Could not move to cart", message: error.errorDescription, preferredStyle: .alert, actions: [WKAlertAction.okAction])
                case .completed:
                    self?.moveToCartButton.setEnabled(true)
                default:
                    return
            }
        }

        disposables += interfaceModel.addToWishListAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            switch event {
                case .value(_):
                    self?.presentAlert(withTitle: "Added to wish list", message: "Product has been added to wish list", preferredStyle: .alert, actions: [WKAlertAction.okAction])
                case let .failed(error):
                    self?.wishListButton.setEnabled(true)
                    self?.presentAlert(withTitle: "Could not add to wish list", message: error.errorDescription, preferredStyle: .alert, actions: [WKAlertAction.okAction])
                default:
                    return
            }
        }

        disposables += interfaceModel.isAddToWishListEnabled.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in
            self?.wishListButton.setEnabled($0)
        }

        updateUserActivity("com.commercetools.Sunrise.viewProductDetails", userInfo: interfaceModel.userActivityInfo, webpageURL: nil)
    }

    @IBAction func moveToCart() {
        moveToCartButton.setEnabled(false)
        disposables += interfaceModel?.moveToCartAction.apply().start()
    }

    @IBAction func addToWishList() {
        wishListButton.setEnabled(false)
        disposables += interfaceModel?.addToWishListAction.apply().start()
    }
}

extension WKAlertAction {
    static var okAction: WKAlertAction {
        return WKAlertAction(title: "OK", style: .default, handler: {})
    }
}
