//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage
import SVProgressHUD

class CartViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGrayColor()
    
    @IBOutlet weak var numberOfItemsLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var viewModel: CartViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = CartViewModel()
        tableView?.layer.borderColor = borderColor.CGColor
        tableView?.tableFooterView = UIView()
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
                self?.tableView.reloadData()
                SVProgressHUD.dismiss()
            }
        })

        observeAlertMessageSignal(viewModel: viewModel)
    }

}

extension CartViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfRowsInSection(section)
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("CartItemCell", forIndexPath: indexPath) as! CartLineItemCell

        guard let viewModel = viewModel else { return cell }

        cell.productNameLabel.text = viewModel.cartItemNameAtIndexPath(indexPath)
        cell.skuLabel.text = viewModel.cartItemSkuAtIndexPath(indexPath)
        cell.sizeLabel.text = viewModel.cartItemSizeAtIndexPath(indexPath)
        cell.priceLabel.text = viewModel.cartItemPriceAtIndexPath(indexPath)
        cell.quantityLabel.text = viewModel.cartItemQuantityAtIndexPath(indexPath)
        cell.totalPriceLabel.text = viewModel.cartItemTotalPriceAtIndexPath(indexPath)
        cell.productImageView.sd_setImageWithURL(NSURL(string: viewModel.cartItemImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        return cell
    }

}