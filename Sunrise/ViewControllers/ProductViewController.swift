//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import IQDropDownTextField
import SDWebImage
import SVProgressHUD

class ProductViewController: UIViewController {

    @IBInspectable var quantityBorderColor: UIColor = UIColor.yellowColor()

    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var sizeField: IQDropDownTextField!
    @IBOutlet weak var skuLabel: UILabel!
    @IBOutlet weak var priceBeforeDiscount: UILabel!
    @IBOutlet weak var activePriceLabel: UILabel!
    @IBOutlet weak var quantityField: IQDropDownTextField!
    @IBOutlet weak var addToCartButton: UIButton!
    
    var viewModel: ProductViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    private var addToCartAction: CocoaAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        sizeField.isOptionalDropDown = false
        sizeField.dropDownMode = .TextPicker

        quantityField.isOptionalDropDown = false
        quantityField.dropDownMode = .TextPicker
        quantityField.layer.borderColor = quantityBorderColor.CGColor

        if viewModel != nil {
            bindViewModel()
        }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        addToCartAction = CocoaAction(viewModel.addToCartAction, { quantity in return quantity as! String })

        viewModel.name.producer
        .observeOn(UIScheduler())
        .startWithNext { [weak self] name in
            self?.productNameLabel.text = name
        }

        viewModel.sizes.producer
        .observeOn(UIScheduler())
        .startWithNext { [weak self] sizes in
            self?.sizeField.itemList = sizes.count > 0 ? sizes : [""]
            self?.sizeField.setSelectedItem(self?.viewModel?.size.value, animated: false)
        }

        viewModel.size.producer
        .observeOn(UIScheduler())
        .startWithNext { [weak self] size in
            self?.sizeField.setSelectedItem(size, animated: false)
        }

        quantityField.itemList = viewModel.quantities
        quantityField.setSelectedItem(viewModel.quantities.first, animated: false)

        viewModel.size <~ sizeField.signalProducer()

        viewModel.sku.producer
            .observeOn(UIScheduler())
            .startWithNext { [weak self] sku in
                self?.skuLabel.text = sku
            }

        viewModel.price.producer
            .observeOn(UIScheduler())
            .startWithNext { [weak self] price in
                self?.activePriceLabel.text = price
            }

        viewModel.oldPrice.producer
            .observeOn(UIScheduler())
            .startWithNext { [weak self] oldPrice in
                let priceBeforeDiscount =  NSMutableAttributedString(string: oldPrice)
                priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
                self?.priceBeforeDiscount.attributedText = priceBeforeDiscount
            }

        viewModel.imageUrl.producer
            .observeOn(UIScheduler())
            .startWithNext { [weak self] imageUrl in
                self?.productImageView.sd_setImageWithURL(NSURL(string: imageUrl))
            }

        viewModel.isLoading.producer
            .observeOn(UIScheduler())
            .startWithNext({ [weak self] isLoading in
                self?.addToCartButton.enabled = !isLoading
                if isLoading {
                    SVProgressHUD.show()
                } else {
                    SVProgressHUD.dismiss()
                }
            })

        viewModel.addToCartAction.events
            .observeOn(UIScheduler())
            .observeNext({ [weak self] event in
                SVProgressHUD.dismiss()
                switch event {
                case .Completed:
                    self?.presentAfterAddingToCartOptions()
                case let .Failed(error):
                    let alertController = UIAlertController(
                            title: "Could not add to cart",
                            message: self?.viewModel?.alertMessageForErrors([error]),
                            preferredStyle: .Alert
                            )
                    alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                    self?.presentViewController(alertController, animated: true, completion: nil)
                default:
                    return
                }
            })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let storeSelectionViewController = segue.destinationViewController as? StoreSelectionViewController,
                storeSelectionViewModel = viewModel?.storeSelectionViewModel {
            storeSelectionViewController.viewModel = storeSelectionViewModel
        }
    }

    @IBAction func addToCart(sender: UIButton) {
        addToCartAction?.execute(quantityField.selectedItem)
    }

    private func presentAfterAddingToCartOptions() {
        let alertController = UIAlertController(
                title: viewModel?.addToCartSuccessTitle,
                message: viewModel?.addToCartSuccessMessage,
                preferredStyle: .Alert
                )
        alertController.addAction(UIAlertAction(title: viewModel?.continueTitle, style: .Default, handler: { _ in
            AppRouting.switchToHome()
        }))
        alertController.addAction(UIAlertAction(title: viewModel?.cartOverviewTitle, style: .Default, handler: { _ in
            AppRouting.switchToCartOverview()
        }))
        presentViewController(alertController, animated: true, completion: nil)
    }

}