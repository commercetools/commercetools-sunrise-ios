//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result
import SDWebImage
import SVProgressHUD
import DZNEmptyDataSet

class ProductOverviewViewController: UICollectionViewController {

    @IBOutlet var noResultsView: UIView!
    @IBInspectable var cellHeight: CGFloat = 270
    
    let searchController = UISearchController(searchResultsController:  nil)

    private var idleTimer: Timer?

    var viewModel: ProductOverviewViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = ProductOverviewViewModel()

        collectionView?.emptyDataSetSource = self
        noResultsView.isHidden = true

        searchController.hidesNavigationBarDuringPresentation = false
        searchController.dimsBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        navigationItem.titleView = searchController.searchBar
        definesPresentationContext = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.willAppearObserver.send(value: ())
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        navigationItem.title = viewModel.title

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            if !isLoading {
                self?.collectionView?.reloadData()
                self?.noResultsView.isHidden = false
                SVProgressHUD.dismiss()
            }
        })

        observeAlertMessageSignal(viewModel: viewModel)

        SVProgressHUD.show()
        viewModel.refreshObserver.send(value: ())
    }

    private func bindViewModel(for productHeaderView: ProductCollectionHeaderView) {
        guard let viewModel = viewModel, isViewLoaded else { return }

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .take(until: productHeaderView.reactive.prepareForReuse)
        .startWithValues({ isLoading in
            if !isLoading {
                [productHeaderView.headerLabel, productHeaderView.myStoreNameLabel].forEach { $0.isHidden = false }
            }
        })
        viewModel.browsingStoreName.producer
        .observe(on: UIScheduler())
        .take(until: productHeaderView.reactive.prepareForReuse)
        .startWithValues({ storeName in
            productHeaderView.myStoreNameLabel.text = storeName
        })
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let selectedCell = sender as? ProductOverviewCell, let indexPath = collectionView?.indexPath(for: selectedCell),
                let productViewController = segue.destination as? ProductViewController, let viewModel = viewModel {
            let productDetailsViewModel = viewModel.productDetailsViewModelForProductAtIndexPath(indexPath)
            productViewController.viewModel = productDetailsViewModel
        }
    }
    
    @IBAction func presentMyStoreSelection(_ sender: UITapGestureRecognizer) {
        AppRouting.switchToMyStore()
    }

    // MARK: - UICollectionViewDataSource

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let viewModel = viewModel else { return 0 }
        return viewModel.numberOfProductsInSection(section)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductOverviewCell", for: indexPath) as! ProductOverviewCell

        guard let viewModel = viewModel else { return cell }

        cell.productNameLabel.text = viewModel.productNameAtIndexPath(indexPath)
        cell.priceLabel.text = viewModel.productPriceAtIndexPath(indexPath)

        let priceBeforeDiscount =  NSMutableAttributedString(string: viewModel.productOldPriceAtIndexPath(indexPath))
        priceBeforeDiscount.addAttribute(NSStrikethroughStyleAttributeName, value: 2, range: NSMakeRange(0, priceBeforeDiscount.length))
        cell.oldPriceLabel.attributedText = priceBeforeDiscount

        cell.productImageView.sd_setImage(with: URL(string: viewModel.productImageUrlAtIndexPath(indexPath)))

        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        if kind == UICollectionElementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "ProductCollectionHeader", for: indexPath) as! ProductCollectionHeaderView
            bindViewModel(for: headerView)
            return headerView
        }
        return UICollectionReusableView()
    }

    // MARK: - UIScrollViewDelegate

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let viewModel = viewModel else { return }

        if viewModel.numberOfProductsInSection(0) > 0 {
            let topOfLastCell = scrollView.contentSize.height - scrollView.frame.height - cellHeight
            let topOfMiddleCell = scrollView.contentSize.height - scrollView.frame.height - CGFloat(viewModel.pageSize) * cellHeight / 2

            // Load new results when the y offset still hasn't reached the bottom.
            // In case it did reach the bottom (i.e user scrolled fast), show the the progress as well.
            if scrollView.contentOffset.y >= topOfMiddleCell && !viewModel.isLoading.value {
                viewModel.nextPageObserver.send(value: ())
            }
            if scrollView.contentOffset.y >= topOfLastCell && viewModel.isLoading.value {
                SVProgressHUD.show()
            }
        }
    }

    // MARK: - Search

    /**
        In order to avoid fetching search results on each change, we use the idleTimer to trigger search action.
    */
    fileprivate func resetIdleTimer() {
        if let idleTimer = idleTimer {
            idleTimer.invalidate()
        }
        idleTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(performSearch), userInfo: nil, repeats: false)
    }

    @objc private func performSearch() {
        if let searchText = searchController.searchBar.text, searchText != viewModel?.searchText.value {
            SVProgressHUD.show()
            viewModel?.searchText.value = searchText
        }
    }

}

// MARK: - UICollectionViewDelegateFlowLayout

extension ProductOverviewViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt sizeForItemAtIndexPath: IndexPath) -> CGSize {
        let screenSize: CGRect = UIScreen.main.bounds
        let cellWidth = (screenSize.width - 26) / 2
        return CGSize(width: cellWidth, height: cellHeight)
    }

}

// MARK: - UISearchResultsUpdating

extension ProductOverviewViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        resetIdleTimer()
    }

}

extension ProductOverviewViewController: DZNEmptyDataSetSource {

    func customView(forEmptyDataSet scrollView: UIScrollView) -> UIView {
        return noResultsView
    }

}
