//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class CartViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loginPromptView: UIView!
    @IBOutlet weak var snapshotBackgroundColorView: UIView!
    @IBOutlet weak var whiteBackgroundColorView: UIView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet var headerView: UIView!
    
    @IBOutlet weak var numerOfItemsLabel: UILabel!
    @IBOutlet weak var orderTotalLabel: UILabel!
    
    @IBOutlet weak var checkoutButton: UIButton!
    @IBOutlet weak var applePayButton: UIButton!
    
    private var backgroundSnapshot: UIImage?
    private var blurredSnapshot: UIImage?
    private let refreshControl = UIRefreshControl()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: CartViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.tableHeaderView = headerView
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
        viewModel = CartViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.15) {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 1
        }
    }
    override func viewDidDisappear(_ animated: Bool) {
        backgroundImageView.alpha = 0
        snapshotBackgroundColorView.alpha = 0
        whiteBackgroundColorView.alpha = 0
        loginPromptView.alpha = 0
        super.viewDidDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            UIView.animate(withDuration: 0.1, animations: {
                self.refreshControl.endRefreshing()
            }, completion: { finished in
                if !self.tableView.isDecelerating, !self.tableView.isTracking {
                    DispatchQueue.main.async {
                        self.updateBackgroundSnapshot()
                    }
                }
            })
            SVProgressHUD.dismiss()
        }

        disposables += numerOfItemsLabel.reactive.text <~ viewModel.numberOfItems
        disposables += orderTotalLabel.reactive.text <~ viewModel.orderTotal
        disposables += checkoutButton.reactive.isEnabled <~ viewModel.isCheckoutEnabled
        disposables += applePayButton.reactive.isEnabled <~ viewModel.isCheckoutEnabled

        disposables += viewModel.contentChangesSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRows(at: changeset.deletions, with: .automatic)
            tableView.reloadRows(at: changeset.modifications, with: .none)
            tableView.insertRows(at: changeset.insertions, with: .automatic)
            tableView.endUpdates()

            if !tableView.isDecelerating, !tableView.isTracking {
                DispatchQueue.main.async {
                    self?.updateBackgroundSnapshot()
                }
            }
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }

        viewModel.refreshObserver.send(value: ())
    }

    @objc private func refresh() {
        viewModel?.refreshObserver.send(value: ())
    }

    @IBAction func checkout(_ sender: UIButton) {
        viewModel?.isAuthenticated == false ? presentLoginPrompt() : performSegue(withIdentifier: "showCheckout", sender: self)
    }

    private func presentLoginPrompt() {
        guard let snapshot = backgroundSnapshot else { return }
        backgroundImageView.image = snapshot
        backgroundImageView.alpha = 1
        UIView.transition(with: backgroundImageView, duration: 0.15, options: .transitionCrossDissolve, animations: {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 0
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 0
            self.backgroundImageView.image = self.blurredSnapshot
        }, completion: { _ in
            self.whiteBackgroundColorView.alpha = 1
            UIView.animate(withDuration: 0.15) {
                self.backgroundImageView.alpha = 0.5
                self.snapshotBackgroundColorView.alpha = 0.5
                self.loginPromptView.alpha = 1
            }
        })
    }

    private func updateBackgroundSnapshot() {
        guard let backgroundSnapshot = takeSnapshot() else { return }
        self.backgroundSnapshot = backgroundSnapshot
        blurredSnapshot = blur(image: backgroundSnapshot)
        if backgroundImageView.alpha > 0 {
            backgroundImageView.image = blurredSnapshot
        }
    }

    private func takeSnapshot() -> UIImage? {
        guard let view = UIApplication.shared.keyWindow?.rootViewController?.view else { return nil }
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        view.layer.render(in: context)
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return snapshot
    }
}

extension CartViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfLineItems ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let lineItemCell = tableView.dequeueReusableCell(withIdentifier: "CartItemCell") as! CartLineItemCell
        guard let viewModel = viewModel else { return lineItemCell }

        lineItemCell.productNameLabel.text = viewModel.lineItemName(at: indexPath)
        lineItemCell.sizeLabel.text = viewModel.lineItemSize(at: indexPath)
        lineItemCell.colorView.backgroundColor = viewModel.lineItemColor(at: indexPath)
        lineItemCell.quantityLabel.text = viewModel.lineItemQuantity(at: indexPath)
        lineItemCell.priceLabel.text = viewModel.lineItemPrice(at: indexPath)
        lineItemCell.priceLabel.textColor = viewModel.lineItemOldPrice(at: indexPath).isEmpty ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)
        lineItemCell.productImageView.sd_setImage(with: URL(string: viewModel.lineItemImageUrl(at: indexPath)), placeholderImage: UIImage(named: "transparent"))
        lineItemCell.oldAndActivePriceSpacingConstraint.constant = viewModel.lineItemOldPrice(at: indexPath).isEmpty ? 0 : 4
        let oldPriceAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Bold", size: 14)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
        lineItemCell.oldPriceLabel.attributedText = NSAttributedString(string: viewModel.lineItemOldPrice(at: indexPath), attributes: oldPriceAttributes)
        lineItemCell.wishListButton.isSelected = viewModel.isLineItemInWishList(at: indexPath)
        disposables += lineItemCell.removeLineItemButton.reactive.controlEvents(.touchUpInside)
        .take(until: lineItemCell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in
            SVProgressHUD.show()
            self?.viewModel?.deleteLineItemObserver.send(value: indexPath)
        }
        disposables += lineItemCell.wishListButton.reactive.controlEvents(.touchUpInside)
        .take(until: lineItemCell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in
            lineItemCell.wishListButton.isSelected = !lineItemCell.wishListButton.isSelected
            self?.viewModel?.toggleWishListObserver.send(value: indexPath)
        }
        return lineItemCell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            viewModel?.deleteLineItemObserver.send(value: indexPath)
        }
    }
}

extension CartViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 198
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let sku = viewModel?.lineItemSku(at: indexPath) else { return }
        AppRouting.showProductDetails(for: sku)
    }
}

extension CartViewController: UIScrollViewDelegate {
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        updateBackgroundSnapshot()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateBackgroundSnapshot()
    }
}
