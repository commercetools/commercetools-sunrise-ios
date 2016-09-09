//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import IQDropDownTextField
import SDWebImage
import SVProgressHUD

class ProductViewController: UITableViewController {

    @IBInspectable var quantityBorderColor: UIColor = UIColor.yellowColor()

    @IBOutlet var headerView: UIView!
    @IBOutlet var footerView: UIView!
    @IBOutlet var displayableAttributesHeaderView: UIView!

    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var skuLabel: UILabel!
    @IBOutlet weak var priceBeforeDiscount: UILabel!
    @IBOutlet weak var activePriceLabel: UILabel!
    @IBOutlet weak var quantityField: IQDropDownTextField!
    @IBOutlet weak var addToCartButton: UIButton!

    private let footerCellIdentifier = "FooterCell"
    private var footerCell: UITableViewCell {
        if let cell = tableView.dequeueReusableCellWithIdentifier(footerCellIdentifier) {
            return cell
        } else {
            let cell = UITableViewCell(style: .Default, reuseIdentifier: footerCellIdentifier)
            cell.contentView.addSubview(footerView)
            return cell
        }
    }
    
    var viewModel: ProductViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    private var addToCartAction: CocoaAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        quantityField.isOptionalDropDown = false
        quantityField.dropDownMode = .TextPicker
        quantityField.layer.borderColor = quantityBorderColor.CGColor
        
        tableView.tableHeaderView = headerView
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50

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

        quantityField.itemList = viewModel.quantities
        quantityField.setSelectedItem(viewModel.quantities.first, animated: false)

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
                    self?.tableView.reloadData()
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

    private func bindSelectableAttributeCell(cell: SelectableAttributeCell, indexPath: NSIndexPath) {
        guard let viewModel = viewModel else { return }

        cell.attributeLabel.text = viewModel.attributeNameAtIndexPath(indexPath)
        cell.attributeField.isOptionalDropDown = false
        cell.attributeField.dropDownMode = .TextPicker
        let attributeKey = viewModel.attributeKeyAtIndexPath(indexPath)

        viewModel.attributes.producer
        .observeOn(UIScheduler())
        .takeUntil(cell.prepareForReuseSignalProducer())
        .startWithNext({ [weak self] attributes in
            if let items = attributes[attributeKey] {
                cell.attributeField.itemList = items.count > 0 ? items : [""]
                cell.attributeField.setSelectedItem(self?.viewModel?.activeAttributes.value[attributeKey], animated: false)
            }
        })

        viewModel.activeAttributes.producer
        .observeOn(UIScheduler())
        .takeUntil(cell.prepareForReuseSignalProducer())
        .startWithNext { activeAttributes in
            if let activeAttribute = activeAttributes[attributeKey] {
                cell.attributeField.setSelectedItem(activeAttribute, animated: false)
            }
        }

        cell.attributeField.signalProducer()
        .takeUntil(cell.prepareForReuseSignalProducer())
        .startWithNext { [weak self] attributeValue in
            self?.viewModel?.activeAttributes.value[attributeKey] = attributeValue
        }
    }

    private func bindDisplayableAttributeCell(cell: DisplayedAttributeCell, indexPath: NSIndexPath) {
        guard let viewModel = viewModel else { return }

        cell.attributeKey.text = viewModel.attributeNameAtIndexPath(indexPath)
        let attributeKey = viewModel.attributeKeyAtIndexPath(indexPath)

        viewModel.activeAttributes.producer
        .observeOn(UIScheduler())
        .takeUntil(cell.prepareForReuseSignalProducer())
        .startWithNext { activeAttributes in
            if let activeAttribute = activeAttributes[attributeKey] {
                cell.attributeValue.text = activeAttribute
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsInSection(section) ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCellWithIdentifier("DisplayedAttributeCell") as! DisplayedAttributeCell
            bindDisplayableAttributeCell(cell, indexPath: indexPath)
            return cell
        }

        let cell = tableView.dequeueReusableCellWithIdentifier("SelectableAttributeCell") as! SelectableAttributeCell
        bindSelectableAttributeCell(cell, indexPath: indexPath)

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
            case 1: return footerView
            case 2: return displayableAttributesHeaderView
            default: return nil
        }
    }

    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
            case 1: return 100
            case 2: return 55
            default: return 0
        }
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