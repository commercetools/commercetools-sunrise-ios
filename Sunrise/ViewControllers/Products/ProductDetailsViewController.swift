//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class ProductDetailsViewController: UIViewController {

    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var similarItemsCollectionView: UICollectionView!
    @IBOutlet weak var imagesCollectionView: UICollectionView!
    @IBOutlet weak var productDescriptionTableView: UITableView!
    @IBOutlet weak var imagesCollectionViewFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var similarItemsGradientView: UIView!
    @IBOutlet weak var isOnStockImageView: UIImageView!
    @IBOutlet weak var cartBadgeImageView: UIImageView!

    @IBOutlet weak var imagesPageControl: UIPageControl!

    @IBOutlet weak var productDescriptionButton: UIButton!
    @IBOutlet weak var reserveInStoreButton: UIButton!
    @IBOutlet weak var addToBagButton: UIButton!
    @IBOutlet weak var wishListButton: UIButton!
    
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var isOnStockLabel: UILabel!
    @IBOutlet weak var cartBadgeLabel: UILabel!
    
    @IBOutlet weak var productDescriptionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var productDescriptionSeparatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var colorSectionWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollableHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var oldAndActivePriceSpacingConstraint: NSLayoutConstraint!

    private let gradientLayer = CAGradientLayer()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: ProductDetailsViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollableHeightConstraint.constant -= productDescriptionHeightConstraint.constant
        productDescriptionHeightConstraint.constant = 0
        NotificationCenter.default.addObserver(forName: Foundation.Notification.Name.Navigation.backButtonTapped, object: nil, queue: .main) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }
        imagesCollectionViewFlowLayout.itemSize = CGSize(width: view.bounds.size.width, height: 500)
        gradientLayer.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.6).cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.frame = similarItemsGradientView.bounds
        similarItemsGradientView.layer.insertSublayer(gradientLayer, at: 0)

        wishListButton.setImage(#imageLiteral(resourceName: "wishlist_icon_active"), for: [.selected, .highlighted])

        cartBadgeLabel.text = SunriseTabBarController.currentlyActive?.cartBadgeLabel.text
        cartBadgeLabel.isHidden = SunriseTabBarController.currentlyActive?.cartBadgeLabel.isHidden ?? true
        cartBadgeImageView.isHidden = SunriseTabBarController.currentlyActive?.cartBadgeImageView.isHidden ?? true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 0
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
        }
        super.viewWillDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += productNameLabel.reactive.text <~ viewModel.name
        disposables += priceLabel.reactive.text <~ viewModel.price
        disposables += priceLabel.reactive.textColor <~ viewModel.priceColor
        disposables += oldPriceLabel.reactive.attributedText <~ viewModel.oldPrice
        disposables += isOnStockLabel.reactive.attributedText <~ viewModel.isOnStock
        disposables += wishListButton.reactive.isSelected <~ viewModel.isProductInWishList

        disposables += viewModel.oldPrice.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] in
            self?.oldAndActivePriceSpacingConstraint.constant = $0 == nil || $0?.string.isEmpty == true ? 0 : 8
        }

        disposables += viewModel.isOnStock.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            self.isOnStockImageView.image = $0?.string == self.viewModel?.onStock ? #imageLiteral(resourceName: "in_stock_checkmark") : #imageLiteral(resourceName: "not_available")
        }

        addToBagButton.reactive.pressed = CocoaAction(viewModel.addToCartAction)
        wishListButton.reactive.pressed = CocoaAction(viewModel.toggleWishListAction)

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss() }

        disposables += viewModel.recommendations.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] _ in self?.similarItemsCollectionView.reloadData() }

        disposables += viewModel.activeAttributes.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] _ in
            self?.colorSectionWidthConstraint.constant = self?.viewModel?.numberOfColors ?? 0 > 1 ? 191 : 148
            self?.colorsCollectionView.isScrollEnabled = self?.viewModel?.numberOfColors ?? 0 > 1
            [self?.sizesCollectionView, self?.colorsCollectionView, self?.imagesCollectionView].forEach { $0?.reloadData() }
            self?.productDescriptionTableView.reloadData()
        }

        disposables += viewModel.imageCount.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] imageCount in
            if imageCount < 2 {
                self?.imagesPageControl.isHidden = true
            } else {
                self?.imagesPageControl.isHidden = false
                self?.imagesPageControl.numberOfPages = imageCount
            }
        }

        disposables += wishListButton.reactive.controlEvents(.touchUpInside)
        .observeValues { [unowned self] _ in
            self.wishListButton.isSelected = !self.wishListButton.isSelected
        }

        disposables += viewModel.addToCartAction.events
        .observe(on: UIScheduler())
        .observeValues({ [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
                case .completed:
                    AppRouting.cartViewController?.viewModel?.refreshObserver.send(value: ())
                    self?.presentAfterAddingToCartOptions()
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: self?.viewModel?.couldNotAddToCartTitle,
                            message: self?.viewModel?.alertMessage(for: [error]),
                            preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                default:
                    return
            }
        })

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
    
    // MARK: - Product description
    
    @IBAction func showHideProductDescription(_ sender: UIButton) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        sender.isSelected = !sender.isSelected
        if !sender.isSelected {
            UIView.animate(withDuration: 0.3, animations: {
                self.scrollableHeightConstraint.constant -= self.productDescriptionHeightConstraint.constant
                self.productDescriptionSeparatorHeightConstraint.constant = 0
                self.productDescriptionHeightConstraint.constant = 0
                self.view.layoutIfNeeded()
            }, completion: { _ in UIApplication.shared.endIgnoringInteractionEvents() })
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.productDescriptionHeightConstraint.constant = CGFloat(self.viewModel?.numberOfDescriptionCells ?? 0) * 70 + 1
                self.productDescriptionSeparatorHeightConstraint.constant = 1
                self.scrollableHeightConstraint.constant += self.productDescriptionHeightConstraint.constant
                self.view.layoutIfNeeded()
            }, completion: { _ in UIApplication.shared.endIgnoringInteractionEvents() })
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let storeSelectionViewController = segue.destination as? StoreSelectionViewController {
            _ = storeSelectionViewController.view
            storeSelectionViewController.viewModel = viewModel?.storeSelectionViewModel
        } else if let detailsViewController = segue.destination as? ProductDetailsViewController, let cell = sender as? UICollectionViewCell,
                  let indexPath = similarItemsCollectionView.indexPath(for: cell) {
            _ = detailsViewController.view
            detailsViewController.viewModel = viewModel?.productDetailsViewModelForRecommendation(at: indexPath)
        }
    }
    
    @IBAction func backAction(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func showCartTab(_ sender: UIButton) {
        AppRouting.switchToCartTab()
    }

    @IBAction func share(_ sender: UIButton) {
        guard let viewModel = viewModel else { return }
        let activityViewController = UIActivityViewController(activityItems: [viewModel.name.value, URL(string: viewModel.shareUrl.value)!], applicationActivities: nil)
        present(activityViewController, animated: true)
    }

    private func presentAfterAddingToCartOptions() {
        let alertController = UIAlertController(
                title: viewModel?.addToCartSuccessTitle,
                message: viewModel?.addToCartSuccessMessage,
                preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: viewModel?.continueTitle, style: .default, handler: { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        }))
        alertController.addAction(UIAlertAction(title: viewModel?.cartOverviewTitle, style: .default, handler: { [weak self] _ in
            AppRouting.switchToCartTab()
            self?.navigationController?.popToRootViewController(animated: false)
        }))
        present(alertController, animated: true, completion: nil)
    }
}

extension ProductDetailsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
            case sizesCollectionView:
                return viewModel?.numberOfSizes ?? 0
            case colorsCollectionView:
                return viewModel?.numberOfColors ?? 0
            case imagesCollectionView:
                return viewModel?.imageCount.value ?? 0
            default:
                return viewModel?.numberOfRecommendations ?? 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let viewModel = viewModel else { return UICollectionViewCell() }
        switch collectionView {
            case sizesCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath) as! SizeCell
                cell.sizeLabel.text = viewModel.sizeName(at: indexPath)
                cell.selectedSizeImageView.isHidden = !viewModel.isSizeActive(at: indexPath)
                cell.sizeLabel.textColor = viewModel.isSizeActive(at: indexPath) ? .white : UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)
                return cell
            case colorsCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
                cell.colorView.backgroundColor = viewModel.color(at: indexPath)
                cell.selectedColorImageView.image = viewModel.color(at: indexPath) != .white ? #imageLiteral(resourceName: "selected_color") : #imageLiteral(resourceName: "selected_color_inverted")
                cell.selectedColorImageView.isHidden = !viewModel.isColorActive(at: indexPath)
                return cell
            case imagesCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductImageCell", for: indexPath) as! ProductImageCell
                cell.productImageView.sd_setImage(with: URL(string: viewModel.productImageUrl(at: indexPath)), placeholderImage: UIImage(named: "sun-placeholder"))
                return cell
            default:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as! ProductOverviewCell
                cell.productNameLabel.text = viewModel.recommendationName(at: indexPath)
                cell.productImageView.sd_setImage(with: URL(string: viewModel.recommendationImageUrl(at: indexPath)))
                let oldPriceAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Bold", size: 12)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
                cell.oldPriceLabel.attributedText = NSAttributedString(string: viewModel.recommendationOldPrice(at: indexPath), attributes: oldPriceAttributes)
                cell.priceLabel.text = viewModel.recommendationPrice(at: indexPath)
                cell.priceLabel.textColor = viewModel.recommendationOldPrice(at: indexPath).isEmpty ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)
                cell.wishListButton.isSelected = viewModel.isProductInWishList(at: indexPath)
                disposables += cell.wishListButton.reactive.controlEvents(.touchUpInside)
                .take(until: cell.reactive.prepareForReuse)
                .observeValues { [weak self] _ in
                    cell.wishListButton.isSelected = !cell.wishListButton.isSelected
                    self?.viewModel?.toggleWishListObserver.send(value: indexPath)
                }
                return cell
        }
    }
}

extension ProductDetailsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfDescriptionCells ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductDescriptionCell") as! ProductDescriptionCell
        cell.descriptionTitleLabel.text = viewModel?.descriptionTitle(at: indexPath)
        cell.descriptionValueLabel.text = viewModel?.descriptionValue(at: indexPath)
        return cell
    }
}

extension ProductDetailsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == colorsCollectionView else { return }
        let centerX = scrollView.contentOffset.x + 20
        for cell in (scrollView as! UICollectionView).visibleCells as! [ColorCell] {

            var offsetX = centerX - cell.center.x
            if offsetX < 0 {
                offsetX *= -1
            }

            cell.transform = CGAffineTransform(scaleX: 1, y: 1)
            if offsetX > 10 {
                var scaleX = 1 - (offsetX - 10) / scrollView.bounds.width
                scaleX = scaleX < 0.773 ? 0.773 : scaleX

                cell.colorView.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                cell.colorView.center = CGPoint(x: cell.contentView.bounds.width / 2 + (1 - scaleX) * cell.contentView.bounds.width / 2, y: cell.contentView.bounds.height / 2)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == colorsCollectionView || scrollView == sizesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: CGPoint(x: 0, y: 0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView == colorsCollectionView || scrollView == sizesCollectionView
                && (!scrollView.isTracking || !scrollView.isDragging)  else { return }
        scrollToPage(scrollView, withVelocity: velocity)
    }

    private func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        let cellWidth = scrollView == colorsCollectionView ? CGFloat(44) : CGFloat(61)
        let cellPadding = scrollView == colorsCollectionView ? CGFloat(5) : CGFloat(10)

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
        guard let selectedIndexPath = (scrollView as? UICollectionView)?.indexPathForItem(at: CGPoint(x: newOffset + cellWidth, y: 0)) else { return }
        scrollView == colorsCollectionView ? viewModel?.selectColorObserver.send(value: selectedIndexPath) : viewModel?.selectSizeObserver.send(value: selectedIndexPath)
    }
}
