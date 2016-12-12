//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result
import IQDropDownTextField
import SDWebImage
import SVProgressHUD

class ProductViewController: UITableViewController {

    @IBInspectable var quantityBorderColor: UIColor = UIColor.yellow

    @IBOutlet var headerView: UIView!
    @IBOutlet var footerView: UIView!
    @IBOutlet var displayableAttributesHeaderView: UIView!
    
    @IBOutlet weak var imagesCollectionView: UICollectionView!
    @IBOutlet weak var imagesCollectionViewFlow: UICollectionViewFlowLayout!
    @IBOutlet weak var imagePageControl: UIPageControl!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var skuLabel: UILabel!
    @IBOutlet weak var priceBeforeDiscount: UILabel!
    @IBOutlet weak var activePriceLabel: UILabel!
    @IBOutlet weak var quantityField: IQDropDownTextField!
    @IBOutlet weak var addToCartButton: UIButton!

    private let footerCellIdentifier = "FooterCell"
    private var footerCell: UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: footerCellIdentifier) {
            return cell
        } else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: footerCellIdentifier)
            cell.contentView.addSubview(footerView)
            return cell
        }
    }
    
    var viewModel: ProductViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    private var addToCartAction: CocoaAction<String>?

    override func viewDidLoad() {
        super.viewDidLoad()

        quantityField.isOptionalDropDown = false
        quantityField.dropDownMode = .textPicker
        quantityField.layer.borderColor = quantityBorderColor.cgColor
        
        tableView.tableHeaderView = headerView
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 50

        // Set the collection view cell width to match the screen width minus the spacing
        imagesCollectionViewFlow.itemSize = CGSize(width: UIScreen.main.bounds.width - 10, height: 210)

        if viewModel != nil {
            bindViewModel()
        }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        addToCartAction = CocoaAction(viewModel.addToCartAction, { quantity in return quantity })

        viewModel.name.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] name in
            self?.productNameLabel.text = name
        }

        quantityField.itemList = viewModel.quantities
        quantityField.setSelectedItem(viewModel.quantities.first, animated: false)

        viewModel.sku.producer
            .observe(on: UIScheduler())
            .startWithValues { [weak self] sku in
                self?.skuLabel.text = sku
            }

        viewModel.price.producer
            .observe(on: UIScheduler())
            .startWithValues { [weak self] price in
                self?.activePriceLabel.text = price
            }

        viewModel.oldPrice.producer
            .observe(on: UIScheduler())
            .startWithValues { [weak self] oldPrice in
                let priceBeforeDiscount =  NSMutableAttributedString(string: oldPrice)
                priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
                self?.priceBeforeDiscount.attributedText = priceBeforeDiscount
            }

        viewModel.imageCount.producer
            .observe(on: UIScheduler())
            .startWithValues { [weak self] imageCount in
                self?.imagesCollectionView.reloadData()
                self?.imagePageControl.numberOfPages = imageCount
            }

        viewModel.isLoading.producer
            .observe(on: UIScheduler())
            .startWithValues({ [weak self] isLoading in
                self?.addToCartButton.isEnabled = !isLoading
                if isLoading {
                    SVProgressHUD.show()
                } else {
                    self?.tableView.reloadData()
                    self?.refreshControl?.endRefreshing()
                    SVProgressHUD.dismiss()
                }
            })

        viewModel.addToCartAction.events
            .observe(on: UIScheduler())
            .observeValues({ [weak self] event in
                SVProgressHUD.dismiss()
                switch event {
                case .completed:
                    self?.presentAfterAddingToCartOptions()
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: "Could not add to cart",
                            message: self?.viewModel?.alertMessage(for: [error]),
                            preferredStyle: .alert
                            )
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                default:
                    return
                }
            })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    private func bindSelectableAttributeCell(_ cell: SelectableAttributeCell, indexPath: IndexPath) {
        guard let viewModel = viewModel else { return }

        cell.attributeField.layer.borderWidth = viewModel.isAttributeSelectableAtIndexPath(indexPath) ? 1 : 0
        cell.attributeField.isEnabled = viewModel.isAttributeSelectableAtIndexPath(indexPath)

        cell.attributeLabel.text = viewModel.attributeNameAtIndexPath(indexPath)
        cell.attributeField.isOptionalDropDown = false
        cell.attributeField.dropDownMode = .textPicker
        let attributeKey = viewModel.attributeKeyAtIndexPath(indexPath)

        viewModel.attributes.producer
        .observe(on: UIScheduler())
        .take(until: cell.reactive.prepareForReuse)
        .startWithValues({ [weak self] attributes in
            if let items = attributes[attributeKey] {
                cell.attributeField.itemList = items.count > 0 ? items : [""]
                cell.attributeField.setSelectedItem(self?.viewModel?.activeAttributes.value[attributeKey], animated: false)
            }
        })

        viewModel.activeAttributes.producer
        .observe(on: UIScheduler())
        .take(until: cell.reactive.prepareForReuse)
        .startWithValues { activeAttributes in
            if let activeAttribute = activeAttributes[attributeKey] {
                cell.attributeField.setSelectedItem(activeAttribute, animated: false)
            }
        }

        cell.attributeField.reactive.continuousTextValues.map({ $0 ?? "" })
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] attributeValue in
            self?.viewModel?.activeAttributes.value[attributeKey] = attributeValue
        }
    }

    private func bindDisplayableAttributeCell(_ cell: DisplayedAttributeCell, indexPath: IndexPath) {
        guard let viewModel = viewModel else { return }

        cell.attributeKey.text = viewModel.attributeNameAtIndexPath(indexPath)
        let attributeKey = viewModel.attributeKeyAtIndexPath(indexPath)

        viewModel.activeAttributes.producer
        .observe(on: UIScheduler())
        .take(until: cell.reactive.prepareForReuse)
        .startWithValues { activeAttributes in
            if let activeAttribute = activeAttributes[attributeKey] {
                cell.attributeValue.text = activeAttribute
            }
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsInSection(section) ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DisplayedAttributeCell") as! DisplayedAttributeCell
            bindDisplayableAttributeCell(cell, indexPath: indexPath)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "SelectableAttributeCell") as! SelectableAttributeCell
        bindSelectableAttributeCell(cell, indexPath: indexPath)

        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
            case 1: return footerView
            case 2: return displayableAttributesHeaderView
            default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
            case 1: return 100
            case 2: return 55
            default: return 0
        }
    }

    // MARK: - Refreshing
    
    @IBAction func refresh(_ sender: UIRefreshControl) {
        viewModel?.refreshObserver.send(value: ())
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let storeSelectionViewController = segue.destination as? StoreSelectionViewController,
                let storeSelectionViewModel = viewModel?.storeSelectionViewModel {
            storeSelectionViewController.viewModel = storeSelectionViewModel
        }
    }
    
    @IBAction func addToCart(_ sender: UIButton) {
        addToCartAction?.execute(quantityField.selectedItem as AnyObject?)
    }

    @IBAction func reserveInStore(_ sender: UIButton) {
        guard let viewModel = viewModel else { return }

        if viewModel.isLoggedIn {
            performSegue(withIdentifier: "showStoreSelection", sender: self)
        } else {
            let alertController = UIAlertController(
                    title: viewModel.logInTitle,
                    message: viewModel.logInMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: viewModel.cancelTitle, style: .cancel, handler: nil))
            alertController.addAction(UIAlertAction(title: viewModel.logInAction, style: .default, handler: { _ in
                AppRouting.presentSignInViewController(tabIndexAfterLogIn: 0)
            }))
            present(alertController, animated: true, completion: nil)
        }
    }
    
    private func presentAfterAddingToCartOptions() {
        let alertController = UIAlertController(
                title: viewModel?.addToCartSuccessTitle,
                message: viewModel?.addToCartSuccessMessage,
                preferredStyle: .alert
                )
        alertController.addAction(UIAlertAction(title: viewModel?.continueTitle, style: .default, handler: { _ in
            AppRouting.switchToHome()
        }))
        alertController.addAction(UIAlertAction(title: viewModel?.cartOverviewTitle, style: .default, handler: { _ in
            AppRouting.switchToCartOverview()
        }))
        present(alertController, animated: true, completion: nil)
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == imagesCollectionView {
            let pageWidth = scrollView.frame.size.width
            imagePageControl.currentPage = Int(floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1)
        }
    }
}

extension ProductViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.imageCount.value
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductImageCell", for: indexPath) as! ProductImageCell

        guard let viewModel = viewModel else { return cell }
        cell.productImageView.sd_setImage(with: URL(string: viewModel.productImageUrl(at: indexPath)))
        return cell
    }
}
