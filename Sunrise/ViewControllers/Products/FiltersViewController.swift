//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa

class FiltersViewController: UIViewController {
    
    @IBOutlet weak var aToGBrandButton: UIButton!
    @IBOutlet weak var hToQBrandButton: UIButton!
    @IBOutlet weak var rToZBrandButton: UIButton!
    @IBOutlet weak var symbolBrandButton: UIButton!
    @IBOutlet weak var resetFiltersButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!

    @IBOutlet weak var lowerPriceLabel: UILabel!
    @IBOutlet weak var higherPriceLabel: UILabel!
    
    @IBOutlet weak var priceSlider: RangeSlider!

    @IBOutlet weak var productTypesCollectionView: UICollectionView!
    @IBOutlet weak var brandsCollectionView: UICollectionView!
    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: FiltersViewModel? {
        didSet {
            bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = FiltersViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.isActive.value = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        viewModel?.isActive.value = false
        super.viewWillDisappear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollViewDidScroll(productTypesCollectionView)
    }

    func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            [self.productTypesCollectionView, self.brandsCollectionView,
             self.sizesCollectionView, self.colorsCollectionView].forEach { $0.reloadData() }
            if let visibleIndexPath = self.brandsCollectionView.indexPathForItem(at: self.brandsCollectionView.contentOffset) {
                self.viewModel?.visibleBrandIndex.value = visibleIndexPath
            }
        }

        let brandButtons = [aToGBrandButton, hToQBrandButton, rToZBrandButton, symbolBrandButton]
        disposables += viewModel.activeBrandButtonIndex.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues {
            brandButtons.forEach { $0?.isSelected = false }
            brandButtons[$0]?.isSelected = true
        }

        disposables += viewModel.scrollBrandAction.values
        .filter { $0 != nil }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.brandsCollectionView.scrollToItem(at: $0!, at: .left, animated: true)
        }

        disposables += viewModel.priceRange.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            guard !self.priceSlider.isTracking else { return }
            self.priceSlider.lowerValue = Double($0.0)
            self.priceSlider.upperValue = Double($0.1)
        }

        disposables += viewModel.priceRange <~ priceSlider.reactive.mapControlEvents(.valueChanged) { (Int($0.lowerValue), Int($0.upperValue)) }
        viewModel.priceSetSignal = priceSlider.reactive.mapControlEvents(.editingDidEnd) { _ in }
        disposables += lowerPriceLabel.reactive.text <~ viewModel.lowerPrice
        disposables += higherPriceLabel.reactive.text <~ viewModel.higherPrice

        aToGBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 0 }
        hToQBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 1 }
        rToZBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 2 }
        symbolBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 3 }
        resetFiltersButton.reactive.pressed = CocoaAction(viewModel.resetFiltersAction)

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
    
    @IBAction func closeFilters(_ sender: UIButton) {
        guard let mainViewController = parent as? MainViewController else { return }
        if mainViewController.searchFilterBackgroundTopConstraint.isActive {
            mainViewController.searchFilter(mainViewController.searchFilterButton)
        } else {
            mainViewController.filter(mainViewController.filterButton)
        }
    }
}

extension FiltersViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        switch collectionView {
            case brandsCollectionView:
                return viewModel.numberOfBrands
            case sizesCollectionView:
                return viewModel.numberOfSizes
            case colorsCollectionView:
                return viewModel.numberOfColors
            default:
                return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
            case brandsCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BrandCell", for: indexPath) as! BrandCell
                cell.brandLabel.text = viewModel?.brandName(at: indexPath)
                cell.selectedBrandImageView.isHidden = viewModel?.isBrandActive(at: indexPath) == false
                return cell
            case sizesCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath) as! SizeCell
                cell.sizeLabel.text = viewModel?.sizeName(at: indexPath)
                cell.selectedSizeImageView.isHidden = viewModel?.isSizeActive(at: indexPath) == false
                cell.sizeLabel.textColor = viewModel?.isSizeActive(at: indexPath) == true ? .white : UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)
                return cell
            case colorsCollectionView:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
                cell.colorView.backgroundColor = viewModel?.color(at: indexPath)
                cell.selectedColorImageView.isHidden = viewModel?.isColorActive(at: indexPath) == false
                return cell
            default:
                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductTypeCell", for: indexPath) as! ProductTypeCell
                cell.selectedProductImageView.isHidden = false
                return cell
        }
    }
}

extension FiltersViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case brandsCollectionView:
            viewModel?.toggleBrandObserver.send(value: indexPath)
        case sizesCollectionView:
            viewModel?.toggleSizeObserver.send(value: indexPath)
        case colorsCollectionView:
            viewModel?.toggleColorObserver.send(value: indexPath)
        default:
            return
        }
    }
}

extension FiltersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let visibleIndexPath = brandsCollectionView.indexPathForItem(at: scrollView.contentOffset), scrollView == brandsCollectionView {
            viewModel?.visibleBrandIndex.value = visibleIndexPath
        }

        guard scrollView == productTypesCollectionView else { return }

        let centerX = scrollView.contentOffset.x + 75
        for cell in (scrollView as! UICollectionView).visibleCells as! [ProductTypeCell] {

            var offsetX = centerX - cell.center.x
            if offsetX < 0 {
                offsetX *= -1
            }

            cell.transform = CGAffineTransform(scaleX: 1, y: 1)
            if offsetX > 30 {
                var scaleX = 1 - (offsetX - 30) / view.bounds.width
                scaleX = scaleX < 0.6 ? 0.6 : scaleX
                let productImageAlpha = 1.5 * scaleX - 0.5
                let productTitleAlpha = 3.33 * scaleX - 2.33

                cell.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                cell.productImageView.alpha = productImageAlpha
                cell.selectedProductImageView.alpha = productImageAlpha
                cell.productNameLabel.alpha = productTitleAlpha
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == productTypesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: CGPoint(x: 0, y: 0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView == productTypesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: velocity)
    }

    func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        let cellWidth = CGFloat(150)
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
    }
}
