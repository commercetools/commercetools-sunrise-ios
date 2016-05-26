//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result
import SDWebImage

class ProductOverviewViewController: UICollectionViewController {

    var viewModel: ProductOverviewViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // After implementing POP search, view model will be instantiated with initial query
        viewModel = ProductOverviewViewModel(limit: 15)
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
            }
        })

        viewModel.alertMessageSignal
        .observeOn(UIScheduler())
        .observeNext({ [weak self] alertMessage in
            let alertController = UIAlertController(
            title: "Oops!",
                    message: alertMessage,
                    preferredStyle: .Alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            self?.presentViewController(alertController, animated: true, completion: nil)
        })
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

}
