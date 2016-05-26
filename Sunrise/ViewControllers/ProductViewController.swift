//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import IQDropDownTextField
import SDWebImage

class ProductViewController: UIViewController {

    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var sizeField: IQDropDownTextField!
    @IBOutlet weak var skuLabel: UILabel!
    @IBOutlet weak var priceBeforeDiscount: UILabel!
    @IBOutlet weak var activePriceLabel: UILabel!
    
    var viewModel: ProductViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        sizeField.isOptionalDropDown = false
        sizeField.dropDownMode = .TextPicker

        if viewModel != nil {
            bindViewModel()
        }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        productNameLabel.text = viewModel.name
        sizeField.itemList = viewModel.sizes
        sizeField.setSelectedItem(viewModel.size.value, animated: false)

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
    }


}