//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage
import SVProgressHUD

class ProductOverviewViewController: UICollectionViewController {

    @IBInspectable var cellHeight: CGFloat = 270

    var viewModel: ProductOverviewViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // After implementing POP search, view model will be instantiated with initial query
        viewModel = ProductOverviewViewModel()
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        navigationItem.title = viewModel.title

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] isLoading in
            if !isLoading {
                self?.collectionView?.reloadData()
                SVProgressHUD.dismiss()
            }
        })

        observeAlertMessageSignal(viewModel: viewModel)

        viewModel.refreshObserver.sendNext()
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let selectedCell = sender as? ProductOverviewCell, indexPath = collectionView?.indexPathForCell(selectedCell),
                productViewController = segue.destinationViewController as? ProductViewController, viewModel = viewModel {
            let productDetailsViewModel = viewModel.productDetailsViewModelForProductAtIndexPath(indexPath)
            productViewController.viewModel = productDetailsViewModel
        }
    }

    // MARK: UICollectionViewDataSource

    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfProductsInSection(section)
    }

    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("ProductOverviewCell", forIndexPath: indexPath) as! ProductOverviewCell

        guard let viewModel = viewModel else { return cell }

        cell.productNameLabel.text = viewModel.productNameAtIndexPath(indexPath)
        cell.priceLabel.text = viewModel.productPriceAtIndexPath(indexPath)

        let priceBeforeDiscount =  NSMutableAttributedString(string: viewModel.productOldPriceAtIndexPath(indexPath))
        priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
        cell.oldPriceLabel.attributedText = priceBeforeDiscount

        cell.productImageView.sd_setImageWithURL(NSURL(string: viewModel.productImageUrlAtIndexPath(indexPath)))

        return cell
    }

    // MARK: UIScrollViewDelegate

    override func scrollViewDidScroll(scrollView: UIScrollView) {
        guard let viewModel = viewModel else { return }

        if viewModel.numberOfProductsInSection(0) > 0 {
            let topOfLastCell = scrollView.contentSize.height - scrollView.frame.height - cellHeight
            let topOfMiddleCell = scrollView.contentSize.height - scrollView.frame.height - CGFloat(viewModel.pageSize) * cellHeight / 2

            // Load new results when the y offset still hasn't reached the bottom.
            // In case it did reach the bottom (i.e user scrolled fast), show the the progress as well.
            if scrollView.contentOffset.y >= topOfMiddleCell && !viewModel.isLoading.value {
                viewModel.nextPageObserver.sendNext()
            }
            if scrollView.contentOffset.y >= topOfLastCell && viewModel.isLoading.value {
                SVProgressHUD.show()
            }
        }
    }

}

// MARK: UICollectionViewDelegateFlowLayout

extension ProductOverviewViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAtIndexPath: NSIndexPath) -> CGSize {
        let screenSize: CGRect = UIScreen.mainScreen().bounds
        let cellWidth = (screenSize.width - 26) / 2
        return CGSize(width: cellWidth, height: cellHeight)
    }

}
