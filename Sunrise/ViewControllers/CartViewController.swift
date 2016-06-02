//
//  CartViewController.swift
//  Sunrise
//
//  Created by Nikola Mladenovic on 5/30/16.
//  Copyright © 2016 Commercetools. All rights reserved.
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
        return viewModel.numberOfItemsInSection(section)
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("CartItemCell", forIndexPath: indexPath) as! CartItemCell

        guard let viewModel = viewModel else { return cell }

        cell.productNameLabel.text = viewModel.itemNameAtIndexPath(indexPath)
        cell.skuLabel.text = viewModel.itemSkuAtIndexPath(indexPath)
        cell.sizeLabel.text = viewModel.itemSizeAtIndexPath(indexPath)
        cell.priceLabel.text = viewModel.itemPriceAtIndexPath(indexPath)
        cell.totalPriceLabel.text = viewModel.itemTotalPriceAtIndexPath(indexPath)
        cell.productImageView.sd_setImageWithURL(NSURL(string: viewModel.itemImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        return cell
    }

}