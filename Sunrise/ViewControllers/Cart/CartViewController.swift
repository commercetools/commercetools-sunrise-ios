//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result
import SDWebImage
import IQDropDownTextField
import DZNEmptyDataSet

class CartViewController: UIViewController {

    @IBInspectable var borderColor: UIColor = UIColor.lightGray
    
    @IBOutlet var emptyCartView: UIView!
    @IBOutlet weak var numberOfItemsLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!

    var viewModel: CartViewModel? {
        didSet {
            bindViewModel()
        }
    }

    private let refreshControl = UIRefreshControl()
    private var disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self

        viewModel = CartViewModel()
        tableView.layer.borderColor = borderColor.cgColor
        tableView.tableFooterView = UIView()

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel?.refreshObserver.send(value: ())
    }

    func bindViewModel() {
        guard let viewModel = viewModel else { return }

        viewModel.numberOfItems.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] numberOfItems in
            self?.numberOfItemsLabel.text = numberOfItems
        })

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            if !isLoading {
                self?.refreshControl.endRefreshing()
            } else {
                self?.refreshControl.beginRefreshing()
            }
        })

        disposables += viewModel.contentChangesSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRows(at: changeset.deletions, with: .automatic)
            tableView.reloadRows(at: changeset.modifications, with: .none)
            tableView.insertRows(at: changeset.insertions, with: .automatic)
            tableView.endUpdates()
        })

        disposables += viewModel.performSegueSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] identifier in
            self?.performSegue(withIdentifier: identifier, sender: nil)
        })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let selectedCell = sender as? CartLineItemCell, let indexPath = tableView.indexPath(for: selectedCell),
                let productViewController = segue.destination as? ProductViewController,
                let productViewModel = viewModel?.productDetailsViewModelForLineItemAtIndexPath(indexPath) {
            productViewController.viewModel = productViewModel
        }
    }

    @objc private func refresh() {
        viewModel?.refreshObserver.send(value: ())
    }

    // MARK: - Binding utilities

    fileprivate func bindCartSummaryCell(_ summaryCell: CartSummaryCell) {
        guard let viewModel = viewModel else { return }

        summaryCell.subtotalLabel.text = viewModel.subtotal.value
        summaryCell.orderDiscountLabel.text = viewModel.orderDiscount.value
        summaryCell.taxLabel.text = viewModel.tax.value
        summaryCell.taxLabel.isHidden = viewModel.taxRowHidden.value
        summaryCell.taxDescriptionLabel.isHidden = viewModel.taxRowHidden.value
        summaryCell.orderTotalLabel.text = viewModel.orderTotal.value
        summaryCell.checkoutButton.reactive.pressed = CocoaAction(viewModel.checkoutAction)
    }

    fileprivate func bindLineItemCell(_ lineItemCell: CartLineItemCell, indexPath: IndexPath) {
        guard let viewModel = viewModel else { return }

        lineItemCell.productNameLabel.text = viewModel.lineItemNameAtIndexPath(indexPath)
        lineItemCell.skuLabel.text = viewModel.lineItemSkuAtIndexPath(indexPath)
        lineItemCell.sizeLabel.text = viewModel.lineItemSizeAtIndexPath(indexPath)
        lineItemCell.priceLabel.text = viewModel.lineItemPriceAtIndexPath(indexPath)
        lineItemCell.quantityField?.delegate = self
        lineItemCell.quantityField?.isOptionalDropDown = false
        lineItemCell.quantityField?.itemList = viewModel.availableQuantities
        lineItemCell.quantityField?.selectedItem = viewModel.lineItemQuantityAtIndexPath(indexPath)
        lineItemCell.totalPriceLabel.text = viewModel.lineItemTotalPriceAtIndexPath(indexPath)
        lineItemCell.productImageView.sd_setImage(with: URL(string: viewModel.lineItemImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        let priceBeforeDiscount =  NSMutableAttributedString(string: viewModel.lineItemOldPriceAtIndexPath(indexPath))
        priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
        lineItemCell.oldPriceLabel.attributedText = priceBeforeDiscount
    }

}

extension CartViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfRowsInSection(section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lineItemCell = tableView.dequeueReusableCell(withIdentifier: "CartItemCell") as! CartLineItemCell

        guard let viewModel = viewModel else { return lineItemCell }

        if indexPath.row == viewModel.numberOfRowsInSection(0) - 1 {
            let summaryCell = tableView.dequeueReusableCell(withIdentifier: "CartSummaryCell") as! CartSummaryCell
            bindCartSummaryCell(summaryCell)
            return summaryCell

        } else {
            bindLineItemCell(lineItemCell, indexPath: indexPath)
            return lineItemCell
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return viewModel?.canDeleteRowAtIndexPath(indexPath) ?? false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            viewModel?.deleteLineItemObserver.send(value: indexPath)
        }
    }

}

extension CartViewController: IQDropDownTextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        if let indexPath = self.tableView.indexPathForRow(at: textField.convert(.zero, to: tableView)),
                let quantity = textField.text {
            viewModel?.updateLineItemQuantityAtIndexPath(indexPath, quantity: quantity)
        }
    }

}

extension CartViewController: DZNEmptyDataSetSource {

    func customView(forEmptyDataSet scrollView: UIScrollView) -> UIView {
        return emptyCartView
    }

}

extension CartViewController: DZNEmptyDataSetDelegate {

    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView) -> Bool {
        return true
    }

}
