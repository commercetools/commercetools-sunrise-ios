//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class CheckoutViewController: UIViewController {

    @IBOutlet weak var lineItemsTableView: UITableView!
    @IBOutlet weak var shippingMethodsTableView: UITableView!
    @IBOutlet weak var deliveryAddressCollectionView: UICollectionView!
    @IBOutlet weak var billingAddressCollectionView: UICollectionView!
    @IBOutlet weak var paymentCollectionView: UICollectionView!
    @IBOutlet weak var passwordMatchImageView: UIImageView!
    @IBOutlet weak var billingAddressGroupView: UIView!
    @IBOutlet var hiddenWhenAuthenticatedViews: [UIView]!
    
    @IBOutlet weak var subtotalLabel: UILabel!
    @IBOutlet weak var discountLabel: UILabel!
    @IBOutlet weak var deliveryLabel: UILabel!
    @IBOutlet weak var taxLabel: UILabel!
    @IBOutlet weak var appliedDiscountCodeInfoLabel: UILabel!
    @IBOutlet var totalLabels: [UILabel]!
    @IBOutlet var discountLabels: [UILabel]!
    @IBOutlet weak var discountCodeField: UITextField!
    @IBOutlet weak var guestEmailField: UITextField!
    @IBOutlet weak var guestPasswordField: UITextField!
    @IBOutlet weak var guestConfirmationField: UITextField!
    @IBOutlet weak var placeOrderButton: UIButton!
    @IBOutlet weak var billingAsShippingSwitch: UISwitch!
    
    @IBOutlet weak var scrollViewContentHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var lineItemsTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var shippingMethodsTableViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var taxDeliveryVerticalSpaceConstraint: NSLayoutConstraint!
    @IBOutlet var billingSameAsShippingConstraints: [NSLayoutConstraint]!
    @IBOutlet var billingNotSameAsShippingConstraints: [NSLayoutConstraint]!
    @IBOutlet var activeWhenNotAuthenticatedConstraints: [NSLayoutConstraint]!
    @IBOutlet var activeWhenAuthenticatedConstraints: [NSLayoutConstraint]!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: CheckoutViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        lineItemsTableView.rowHeight = UITableView.automaticDimension
        shippingMethodsTableView.rowHeight = UITableView.automaticDimension

        billingAsShippingSwitch.onTintColor = UIColor(patternImage: #imageLiteral(resourceName: "switch_background"))
        hiddenWhenAuthenticatedViews.forEach { $0.isHidden = true }

        viewModel = CheckoutViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.3) {
            self.activeWhenNotAuthenticatedConstraints.forEach { $0.isActive = self.viewModel?.isAuthenticated == false }
            self.activeWhenAuthenticatedConstraints.forEach { $0.isActive = self.viewModel?.isAuthenticated == true }
            self.hiddenWhenAuthenticatedViews.forEach { $0.isHidden = self.viewModel?.isAuthenticated == true }
            self.view.layoutIfNeeded()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
        super.viewWillDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        placeOrderButton.reactive.pressed = CocoaAction(viewModel.orderAction)

        totalLabels.forEach { disposables += $0.reactive.text <~ viewModel.orderTotal }

        disposables += viewModel.isBillingSameAsShipping <~ billingAsShippingSwitch.reactive.isOnValues

        disposables += viewModel.discountCode <~ discountCodeField.reactive.textValues
        disposables += subtotalLabel.reactive.text <~ viewModel.subtotal
        disposables += deliveryLabel.reactive.text <~ viewModel.shippingPrice
        disposables += appliedDiscountCodeInfoLabel.reactive.text <~ viewModel.appliedDiscountCodeInfo

        disposables += viewModel.guestEmail <~ guestEmailField.reactive.continuousTextValues
        disposables += viewModel.guestPassword <~ guestPasswordField.reactive.continuousTextValues
        disposables += viewModel.guestPasswordConfirmation <~ guestConfirmationField.reactive.continuousTextValues
        disposables += passwordMatchImageView.reactive.isHidden <~ viewModel.isOrderValid.map { !$0 }

        disposables += taxLabel.reactive.text <~ viewModel.tax
        disposables += discountLabel.reactive.text <~ viewModel.orderDiscount
        disposables += viewModel.orderDiscount.signal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] orderDiscount in
            UIView.animate(withDuration: 0.3) {
                self.taxDeliveryVerticalSpaceConstraint.constant = orderDiscount.isEmpty ? 14 : 45
                self.discountLabels.forEach { $0.alpha = orderDiscount.isEmpty ? 0 : 1 }
                self.view.layoutIfNeeded()
            }
        }

        disposables += placeOrderButton.reactive.isEnabled <~ viewModel.isOrderValid

        disposables += viewModel.isBillingSameAsShipping.combinePrevious(true).signal
        .filter { !$0  || !$1 }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _, current in
            self.setBillingSectionHidden(current)
        }

        disposables += viewModel.isBillingSameAsShipping.signal
        .observe(on: UIScheduler())
        .filter { [unowned self] in self.billingAsShippingSwitch.isOn != $0 }
        .observeValues { [unowned self] in
            self.billingAsShippingSwitch.isOn = $0
        }

        disposables += viewModel.noActiveCartSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in self.presentNoActiveCartError() }

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss()
            if !$0 {
                self.shippingMethodsTableView.reloadData()
            }
        }

        disposables += viewModel.numberOfLineItems.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] numberOfLineItems in
            self.lineItemsTableView.reloadData()
            DispatchQueue.main.async {
                let newHeight = (0..<numberOfLineItems).reduce(CGFloat(0), { $0 + self.lineItemsTableView.rectForRow(at: IndexPath(row: $1, section: 0)).height })
                self.scrollViewContentHeightConstraint.constant += newHeight - self.lineItemsTableViewHeightConstraint.constant
                self.lineItemsTableViewHeightConstraint.constant = newHeight
            }
        }

        disposables += viewModel.methods.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] methods in
            self.shippingMethodsTableView.reloadData()
            DispatchQueue.main.async {
                let newHeight = (0..<methods.count).reduce(CGFloat(0), { $0 + self.shippingMethodsTableView.rectForRow(at: IndexPath(row: $1, section: 0)).height })
                self.scrollViewContentHeightConstraint.constant += newHeight - self.shippingMethodsTableViewHeightConstraint.constant
                self.shippingMethodsTableViewHeightConstraint.constant = newHeight
            }
        }

        disposables += viewModel.shippingAddresses.producer
        .skip(first: 2)
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.deliveryAddressCollectionView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            self.deliveryAddressCollectionView.reloadSections([0])
            self.scrollViewDidScroll(self.deliveryAddressCollectionView)
        }

        disposables += viewModel.billingAddresses.producer
        .skip(first: 2)
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.billingAddressCollectionView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            self.billingAddressCollectionView.reloadSections([0])
            self.scrollViewDidScroll(self.billingAddressCollectionView)
        }

        disposables += viewModel.creditCards.producer
        .skip(first: 2)
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.paymentCollectionView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
            self.paymentCollectionView.reloadSections([0])
            self.scrollViewDidScroll(self.paymentCollectionView)
        }

        self.paymentCollectionView.reloadSections([0])
        self.scrollViewDidScroll(self.paymentCollectionView)

        disposables += viewModel.orderAction.events
        .observe(on: UIScheduler())
        .observeValues { [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
                case .value:
                    self?.performSegue(withIdentifier: "showOrderConfirmation", sender: self)
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: self?.viewModel?.oopsTitle,
                            message: self?.viewModel?.alertMessage(for: [error]),
                            preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                default:
                    return
            }
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    private func setBillingSectionHidden(_ hidden: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.billingAddressGroupView.alpha = hidden ? 0 : 1
            if hidden {
                self.billingNotSameAsShippingConstraints.forEach { $0.isActive = false }
                self.billingSameAsShippingConstraints.forEach { $0.isActive = true }
                self.scrollViewContentHeightConstraint.constant -= 228
            } else {
                self.billingSameAsShippingConstraints.forEach { $0.isActive = false }
                self.billingNotSameAsShippingConstraints.forEach { $0.isActive = true }
                self.scrollViewContentHeightConstraint.constant += 228
            }
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.destination {
            case let addressViewController as AddressViewController:
                _ = addressViewController.view
                _ = addressViewController.checkoutHeaderViews.forEach { $0.isHidden = false }
                if let sender = sender as? UIButton, let cell = sender.superview?.superview as? AddressCell {
                    if let indexPath = deliveryAddressCollectionView.indexPath(for: cell), let viewModel = viewModel?.addressViewModelForAddress(at: indexPath, type: .shipping) {
                        addressViewController.viewModel = viewModel
                    } else if let indexPath = billingAddressCollectionView.indexPath(for: cell), let viewModel = viewModel?.addressViewModelForAddress(at: indexPath, type: .billing) {
                        addressViewController.viewModel = viewModel
                    }

                } else if let sender = sender as? UICollectionViewCell {
                    addressViewController.viewModel = AddressViewModel(address: nil, type: deliveryAddressCollectionView.indexPath(for: sender) != nil ? .shipping : .billing)
                }
            case let paymentViewController as PaymentViewController:
                _ = paymentViewController.view
                _ = paymentViewController.checkoutHeaderViews.forEach { $0.isHidden = false }
                if let sender = sender as? UIButton, let cell = sender.superview?.superview as? PaymentCell {
                    if let indexPath = paymentCollectionView.indexPath(for: cell), let viewModel = viewModel?.paymentViewModelForPayment(at: indexPath) {
                        paymentViewController.viewModel = viewModel
                    }

                } else if sender is UICollectionViewCell {
                    paymentViewController.viewModel = PaymentViewModel()
                }
            default:
                return
        }

    }

    private func presentNoActiveCartError() {
        let alertController = UIAlertController(
                title: viewModel?.oopsTitle,
                message: viewModel?.noActiveCartMessage,
                preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: viewModel?.okAction, style: .cancel, handler: { [weak self] _ in
            self?.quitCheckout()
        }))
        present(alertController, animated: true, completion: nil)
    }

    private func quitCheckout() {
        (((presentingViewController as? UINavigationController)?.viewControllers.last as? UITabBarController)?.viewControllers?[5] as? UINavigationController)?.popViewController(animated: false)
        dismiss(animated: true)
    }

    @IBAction func dismissCheckout(_ sender: UIButton) {
        quitCheckout()
    }
}

extension CheckoutViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
            case deliveryAddressCollectionView:
                return (viewModel?.shippingAddresses.value.count ?? 0) + 1
            case billingAddressCollectionView:
                return (viewModel?.billingAddresses.value.count ?? 0) + 1
            case paymentCollectionView:
                return (viewModel?.creditCards.value.count ?? 0) + 1
            default:
                return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch (collectionView, indexPath.item) {
            case (deliveryAddressCollectionView, 0..<collectionView.numberOfItems(inSection: 0) - 1), (billingAddressCollectionView, 0..<collectionView.numberOfItems(inSection: 0) - 1):
                let type = collectionView == billingAddressCollectionView ? CheckoutViewModel.AddressType.billing : .shipping
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddressCell", for: indexPath) as! AddressCell
                resetScale(for: cell)
                cell.nameLabel.text = viewModel?.addressName(at: indexPath, for: type)
                cell.detailsLabel.text = viewModel?.addressDetails(at: indexPath, for: type)
                cell.cellSelectedImageView?.alpha = viewModel?.isAddressSelected(at: indexPath, for: type) == true ? 1 : 0
                return cell
            case (_, collectionView.numberOfItems(inSection: 0) - 1):
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddNewCell", for: indexPath)
                resetScale(for: cell)
                return cell
            default:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaymentCell", for: indexPath) as! PaymentCell
                resetScale(for: cell)
                cell.last4DigitsLabel.text = viewModel?.cardLast4Digits(at: indexPath)
                cell.nameLabel.text = viewModel?.cardName(at: indexPath)
                return cell
        }
    }
}

extension CheckoutViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == lineItemsTableView ? viewModel?.numberOfLineItems.value ?? 0 : viewModel?.methods.value.count ?? 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel else { return UITableViewCell() }
        if tableView == lineItemsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LineItemCell") as! CheckoutLineItemCell
            cell.productNameLabel.text = viewModel.lineItemName(at: indexPath)
            cell.quantityLabel.text = viewModel.lineItemQuantity(at: indexPath)
            cell.priceLabel.text = viewModel.lineItemPrice(at: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ShippingMethodCell") as! ShippingMethodCell
            cell.nameLabel.text = viewModel.shippingMethodName(at: indexPath)
            cell.descriptionLabel.text = viewModel.shippingMethodDescription(at: indexPath)
            cell.priceLabel.text = viewModel.shippingMethodPrice(at: indexPath)
            cell.selectButton.isSelected = viewModel.isShippingMethodSelected(at: indexPath)
            disposables += cell.selectButton.reactive.controlEvents(.touchUpInside)
            .take(until: cell.reactive.prepareForReuse)
            .observeValues { [weak self] _ in
                cell.selectButton.isSelected = true
                self?.viewModel?.pickShippingMethodObserver.send(value: indexPath)
            }
            return cell
        }
    }
}

extension CheckoutViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = scrollView as? UICollectionView else { return }
        let centerX = scrollView.contentOffset.x + 130
        for cell in collectionView.visibleCells {

            var offsetX = centerX - cell.center.x
            if offsetX < 0 {
                offsetX *= -1
            }

            resetScale(for: cell)
            if offsetX > 30 {
                var scaleX = 1 - (offsetX - 30) / scrollView.bounds.width
                scaleX = scaleX < 0.598 ? 0.598 : scaleX


                cell.contentView.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                cell.contentView.alpha = scaleX
                cell.contentView.center = CGPoint(x: cell.contentView.bounds.width / 2 - (1 - scaleX) * cell.contentView.bounds.width / 2, y: cell.contentView.bounds.height / 2)
                if let cell = cell as? AddressCell {
                    cell.cellSelectedImageView?.alpha = scaleX * 2.488 - 1.488
                }
                if let cell = cell as? PaymentCell {
                    cell.cellSelectedImageView?.alpha = scaleX * 2.488 - 1.488
                }
            }
        }
    }

    func resetScale(for cell: UICollectionViewCell) {
        cell.contentView.transform = CGAffineTransform.identity
        cell.contentView.alpha = 1
        cell.contentView.center = CGPoint(x: cell.contentView.bounds.width / 2, y: cell.contentView.bounds.height / 2)
        if let cell = cell as? AddressCell {
            cell.cellSelectedImageView?.alpha = 1
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView is UICollectionView else { return }
        scrollToPage(scrollView, withVelocity: CGPoint(x: 0, y: 0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView is UICollectionView else { return }
        scrollToPage(scrollView, withVelocity: velocity)
    }

    func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        guard scrollView is UICollectionView else { return }
        let cellWidth = CGFloat(260)
        let cellPadding = CGFloat(10)

        var page: Int = Int((scrollView.contentOffset.x - cellWidth / 2) / (cellWidth + cellPadding) + 1)
        if velocity.x > 0 {
            page += 1
        }
        if velocity.x < 0 {
            page -= 1
        }
        page = max(page, 0)
        let newOffset: CGFloat = CGFloat(page) * (cellWidth + cellPadding)
        scrollView.setContentOffset(CGPoint(x: newOffset, y: 0), animated: true)
        guard let selectedIndexPath = (scrollView as? UICollectionView)?.indexPathForItem(at: CGPoint(x: newOffset, y: 0)) else { return }
        switch scrollView {
            case deliveryAddressCollectionView:
                viewModel?.selectedShippingAddressIndexPath.value = selectedIndexPath
            case billingAddressCollectionView:
                viewModel?.selectedBillingAddressIndexPath.value = selectedIndexPath
            case paymentCollectionView:
                viewModel?.selectedPaymentIndexPath.value = selectedIndexPath
            default:
                return
        }
    }
}
