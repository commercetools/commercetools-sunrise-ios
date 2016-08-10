//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage

class CartViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGrayColor()
    
    @IBOutlet weak var numberOfItemsLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var viewModel: CartViewModel? {
        didSet {
            bindViewModel()
        }
    }

    private let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = CartViewModel()
        tableView.layer.borderColor = borderColor.CGColor
        tableView.tableFooterView = UIView()

        refreshControl.addTarget(self, action: #selector(refresh), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        viewModel?.refreshObserver.sendNext()
    }

    func bindViewModel() {
        guard let viewModel = viewModel else { return }

        viewModel.numberOfItems.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] numberOfItems in
            self?.numberOfItemsLabel.text = numberOfItems
        })

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] isLoading in
            if !isLoading {
                self?.refreshControl.endRefreshing()
            } else {
                self?.refreshControl.beginRefreshing()
            }
        })

        viewModel.contentChangesSignal
        .observeOn(UIScheduler())
        .observeNext({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRowsAtIndexPaths(changeset.deletions, withRowAnimation: .Automatic)
            tableView.reloadRowsAtIndexPaths(changeset.modifications, withRowAnimation: .None)
            tableView.insertRowsAtIndexPaths(changeset.insertions, withRowAnimation: .Automatic)
            tableView.endUpdates()
        })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    @objc private func refresh() {
        viewModel?.refreshObserver.sendNext()
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
        lineItemCell.quantityLabel.text = viewModel.lineItemQuantityAtIndexPath(indexPath)
        lineItemCell.totalPriceLabel.text = viewModel.lineItemTotalPriceAtIndexPath(indexPath)
        lineItemCell.productImageView.sd_setImageWithURL(NSURL(string: viewModel.lineItemImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        let priceBeforeDiscount =  NSMutableAttributedString(string: viewModel.lineItemOldPriceAtIndexPath(indexPath))
        priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
        lineItemCell.oldPriceLabel.attributedText = priceBeforeDiscount
    }

}

extension CartViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfRowsInSection(section)
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let lineItemCell = tableView.dequeueReusableCellWithIdentifier("CartItemCell") as! CartLineItemCell

        guard let viewModel = viewModel else { return lineItemCell }

        if indexPath.row == viewModel.numberOfRowsInSection(0) - 1 {
            let summaryCell = tableView.dequeueReusableCellWithIdentifier("CartSummaryCell") as! CartSummaryCell
            bindCartSummaryCell(summaryCell)
            return summaryCell

        } else {
            bindLineItemCell(lineItemCell, indexPath: indexPath)
            return lineItemCell
        }
    }

    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return viewModel?.canDeleteRowAtIndexPath(indexPath) ?? false
    }

    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            viewModel?.deleteLineItemObserver.sendNext(indexPath)
        }
    }

}