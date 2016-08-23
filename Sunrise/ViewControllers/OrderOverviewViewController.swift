//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage

class OrderOverviewViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGrayColor()

    @IBOutlet weak var numberOfItemsLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var viewModel: OrderOverviewViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.layer.borderColor = borderColor.CGColor
        tableView.tableFooterView = UIView()

        if viewModel != nil {
            bindViewModel()
        }
    }

    // MARK: - Bindings

    func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        viewModel.numberOfItems.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] numberOfItems in
            self?.numberOfItemsLabel.text = numberOfItems
        })

        viewModel.order.producer
        .observeOn(UIScheduler())
        .startWithNext { [weak self] _ in
            self?.tableView.reloadData()
        }
    }

    private func bindCartSummaryCell(summaryCell: CartSummaryCell) {
        guard let viewModel = viewModel else { return }

        summaryCell.subtotalLabel.text = viewModel.subtotal.value
        summaryCell.orderDiscountLabel.text = viewModel.orderDiscount.value
        summaryCell.taxLabel.text = viewModel.tax.value
        summaryCell.taxLabel.hidden = viewModel.taxRowHidden.value
        summaryCell.taxDescriptionLabel.hidden = viewModel.taxRowHidden.value
        summaryCell.orderTotalLabel.text = viewModel.orderTotal.value
    }

    private func bindLineItemCell(lineItemCell: CartLineItemCell, indexPath: NSIndexPath) {
        guard let viewModel = viewModel else { return }

        lineItemCell.productNameLabel.text = viewModel.lineItemNameAtIndexPath(indexPath)
        lineItemCell.skuLabel.text = viewModel.lineItemSkuAtIndexPath(indexPath)
        lineItemCell.sizeLabel.text = viewModel.lineItemSizeAtIndexPath(indexPath)
        lineItemCell.priceLabel.text = viewModel.lineItemPriceAtIndexPath(indexPath)
        lineItemCell.quantityLabel?.text = viewModel.lineItemQuantityAtIndexPath(indexPath)
        lineItemCell.totalPriceLabel.text = viewModel.lineItemTotalPriceAtIndexPath(indexPath)
        lineItemCell.productImageView.sd_setImageWithURL(NSURL(string: viewModel.lineItemImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        let priceBeforeDiscount =  NSMutableAttributedString(string: viewModel.lineItemOldPriceAtIndexPath(indexPath))
        priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
        lineItemCell.oldPriceLabel.attributedText = priceBeforeDiscount
    }

}

// MARK: - UITableViewDataSource

extension OrderOverviewViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfRowsInSection(section)
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let lineItemCell = tableView.dequeueReusableCellWithIdentifier("OrderItemCell") as! CartLineItemCell

        guard let viewModel = viewModel else { return lineItemCell }

        if indexPath.row == viewModel.numberOfRowsInSection(0) - 1 {
            let summaryCell = tableView.dequeueReusableCellWithIdentifier("OrderSummaryCell") as! CartSummaryCell
            bindCartSummaryCell(summaryCell)
            return summaryCell

        } else {
            bindLineItemCell(lineItemCell, indexPath: indexPath)
            return lineItemCell
        }
    }

}

// MARK: - UITableViewDelegate

extension OrderOverviewViewController: UITableViewDelegate {

    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        guard let viewModel = viewModel else { return 0 }
        let numberOfRows = viewModel.numberOfRowsInSection(indexPath.section)
        return indexPath.row == numberOfRows - 1 ? 150 : 225
    }

}