//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import CoreLocation
import ReactiveSwift
import SVProgressHUD

class MainViewController: UIViewController {

    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var filtersView: UIView!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var categoriesDropdownGradientView: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var categoriesDropdownView: UIView!
    @IBOutlet weak var emptyStateView: UIScrollView!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    @IBOutlet weak var productsCollectionView: UICollectionView!
    @IBOutlet weak var searchSuggestionsTableView: UITableView!
    @IBOutlet weak var subcategoriesTableView: UITableView!
    @IBOutlet weak var magnifyingGlassImageView: UIImageView!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var snapshotBackgroundColorView: UIView!
    @IBOutlet weak var whiteBackgroundColorView: UIView!
    @IBOutlet weak var categorySelectionButton: UIButton!
    @IBOutlet weak var searchFilterButton: UIButton!
    @IBOutlet weak var searchFilterBackgroundTopImageView: UIImageView!
    @IBOutlet weak var searchFilterMyStyleAppliedImageView: UIImageView!
    @IBOutlet weak var filterMyStyleAppliedImageView: UIImageView!
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var filterBackgroundTopImageView: UIImageView!

    @IBOutlet weak var searchViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldMagnifyingGlassLeadingSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var categorySelectionButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldLineCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var categoriesDropdownCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFilterBackgroundTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterBackgroundTopConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthActiveConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthInactiveConstraint: NSLayoutConstraint!

    private weak var filtersViewController: FiltersViewController?
    private let gradientLayer = CAGradientLayer()
    private let categoriesDropdownGradientLayer = CAGradientLayer()
    private var screenSnapshot: UIImage?
    private var backgroundSnapshot: UIImage?
    private var blurredSnapshot: UIImage?
    private let locationManager = CLLocationManager()
    private var isTransitioningToProducts = false
    private let productsCellHeight: CGFloat = 311
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: MainViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        [gradientLayer, categoriesDropdownGradientLayer].forEach { $0.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] }
        gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 13)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
        categoriesDropdownCenterXConstraint.constant = 0.016 * view.bounds.width
        categoriesDropdownGradientLayer.frame = categoriesDropdownGradientView.bounds
        categoriesDropdownGradientView.layer.insertSublayer(categoriesDropdownGradientLayer, at: 0)
        subcategoriesTableView.contentInset = UIEdgeInsetsMake(17, 0, 0, 0)

        let placeholderAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red: 0.34, green: 0.37, blue: 0.40, alpha: 1.0)]
        searchField.attributedPlaceholder = NSAttributedString(string: "search", attributes: placeholderAttributes)

        [searchSuggestionsTableView, subcategoriesTableView].forEach { $0.tableFooterView = UIView() }
        subcategoriesTableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: subcategoriesTableView.bounds.width, height: 0.5))
        subcategoriesTableView.tableHeaderView?.backgroundColor = subcategoriesTableView.separatorColor

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        viewModel = MainViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if productsCollectionView.alpha == 1 {
            productsCollectionView.reloadData()
        }
    }

    func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += categorySelectionButton.reactive.title <~ viewModel.activeCategoryName
        disposables += categorySelectionButton.reactive.title(for: [.normal, .highlighted]) <~ viewModel.activeCategoryName
        disposables += categorySelectionButton.reactive.title(for: [.highlighted, .selected]) <~ viewModel.activeCategoryName
        disposables += categorySelectionButton.reactive.title(for: [.selected]) <~ viewModel.activeCategoryName

        disposables += viewModel.activeCategoryName.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] name in
            self?.subcategoriesTableView.reloadData()
            guard self?.isTransitioningToProducts == false else { return }
            self?.categoriesCollectionView.reloadData()
            self?.checkAndPresentEmptyState()
            DispatchQueue.main.async {
                self?.updateBackgroundSnapshot()
            }
        }

        disposables += viewModel.selectedCategoryTableRowSignal
        .delay(0.1, on: QueueScheduler(qos: .userInteractive))
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            self.removeCategoriesDropdownPicker()
        }

        disposables += viewModel.presentProductOverviewSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.presentProductOverview()
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.resetSearch)
        .observe(on: UIScheduler())
        .observeValues { [weak self] _ in
            self?.backToCategoryOverview()
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [weak self] _ in
            guard self?.view.window != nil else { return }
            self?.searchField.text = ""
            self?.searchField.resignFirstResponder()
            self?.updateBackgroundSnapshot()
        }

        disposables += searchField.reactive.textValues
        .filter { $0 != "" }
        .observe(on: UIScheduler())
        .observeValues { [weak self] _ in
            self?.presentSearchResults()
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
        bindProductsViewModel()
    }

    func bindProductsViewModel() {
        guard let viewModel = viewModel?.productsViewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.productsCollectionView.reloadData()
            self.checkAndPresentEmptyState()
            self.updateFilterButtonSelectedState()
            SVProgressHUD.dismiss()
            if !self.productsCollectionView.isDecelerating, !self.productsCollectionView.isTracking {
                DispatchQueue.main.async {
                    self.updateBackgroundSnapshot()
                }
            }
        }

        disposables += viewModel.textSearch <~ searchField.reactive.textValues.map { ($0 ?? "", Locale.current) }

        disposables += searchField.reactive.textValues
        .filter { $0 != "" }
        .delay(0.1, on: QueueScheduler(qos: .userInteractive))
        .observe(on: UIScheduler())
        .observeValues { [weak self] _ in
            self?.searchSuggestionsTableView.reloadData()
        }

        disposables += viewModel.presentProductDetailsSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] productViewModel in
            self?.performSegue(withIdentifier: "showProductDetails", sender: productViewModel)
        }

        viewModel.filtersViewModel = filtersViewController?.viewModel

        bindFiltersViewModel()

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    func bindFiltersViewModel() {
        guard let viewModel = viewModel?.productsViewModel.filtersViewModel, isViewLoaded else { return }

        disposables += viewModel.isMyStyleApplied.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            switch ($0, self.filterButton.isSelected) {
                case (true, true):
                    self.filterMyStyleAppliedImageView.alpha = 1
                case (true, false):
                    self.searchFilterMyStyleAppliedImageView.alpha = 1
                case (false, _):
                    [self.filterMyStyleAppliedImageView, self.searchFilterMyStyleAppliedImageView].forEach { $0.alpha = 0 }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateBackgroundSnapshot()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let filtersViewController = segue.destination as? FiltersViewController {
            self.filtersViewController = filtersViewController
            _ = filtersViewController.view
        } else if let recommendationsViewController = segue.destination as? InlineProductOverviewViewController {
            _ = recommendationsViewController.view
            recommendationsViewController.viewModel = CartViewModel.recommendationsViewModel
        } else if let detailsViewController = segue.destination as? ProductDetailsViewController {
            _ = detailsViewController.view
            if let cell = sender as? UICollectionViewCell, let indexPath = productsCollectionView.indexPath(for: cell) {
                detailsViewController.viewModel = viewModel?.productsViewModel.productDetailsViewModelForProduct(at: indexPath)
            } else if let viewModel = sender as? ProductDetailsViewModel {
                detailsViewController.viewModel = viewModel
            }
        }
    }

    @IBAction func searchFilter(_ sender: UIButton) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        if filtersView.alpha == 1 {
            UIView.animate(withDuration: 0.3, animations: {
                self.searchFilterBackgroundTopImageView.alpha = 0
                self.filtersView.alpha = 0
                SunriseTabBarController.currentlyActive?.tabView.alpha = 1
            }, completion: { _ in UIApplication.shared.endIgnoringInteractionEvents() })
            sender.isSelected = viewModel?.productsViewModel.filtersViewModel?.hasFiltersApplied == true

        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.filterBackgroundTopConstraint.isActive = false
                self.searchFilterBackgroundTopConstraint.isActive = true
                self.searchFilterBackgroundTopImageView.alpha = 1
                self.filtersView.alpha = 1
                SunriseTabBarController.currentlyActive?.tabView.alpha = 0
                self.view.layoutIfNeeded()
            }, completion: { _ in UIApplication.shared.endIgnoringInteractionEvents() })
            sender.isSelected = true
        }
    }

    @IBAction func filter(_ sender: UIButton) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        if filtersView.alpha == 1 {
            UIView.animate(withDuration: 0.3, animations: {
                self.filterBackgroundTopImageView.alpha = 0
                self.filtersView.alpha = 0
                SunriseTabBarController.currentlyActive?.tabView.alpha = 1
            }, completion: { _ in UIApplication.shared.endIgnoringInteractionEvents() })
            sender.isSelected = viewModel?.productsViewModel.filtersViewModel?.hasFiltersApplied == true

        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.searchFilterBackgroundTopConstraint.isActive = false
                self.filterBackgroundTopConstraint.isActive = true
                self.filterBackgroundTopImageView.alpha = 1
                self.filtersView.alpha = 1
                SunriseTabBarController.currentlyActive?.tabView.alpha = 0
                self.view.layoutIfNeeded()
            }, completion: { _ in UIApplication.shared.endIgnoringInteractionEvents() })
            sender.isSelected = true
        }
    }

    @IBAction func searchEditingDidBegin(_ sender: UITextField) {
        viewModel?.productsViewModel.clearProductsObserver.send(value: ())
        UIView.animate(withDuration: 0.3, animations: {
            self.checkAndPresentEmptyState()
            self.magnifyingGlassImageView.image = #imageLiteral(resourceName: "search_field_icon_active")
            self.searchFieldMagnifyingGlassLeadingSpaceConstraint.constant = 0
            self.categorySelectionButton.alpha = 0
            self.searchFilterButton.alpha = 0
            SunriseTabBarController.currentlyActive?.backButton.alpha = 1
            self.searchFieldLineCenterXConstraint.constant = 0
            self.searchFieldLineWidthInactiveConstraint.isActive = false
            self.searchFieldLineWidthActiveConstraint.isActive = true
            self.searchFieldLineWidthActiveConstraint.constant = 0
            [self.productsCollectionView, self.categoriesCollectionView].forEach { $0?.alpha = 0 }
            self.searchView.layoutIfNeeded()
        }, completion: { _ in
            self.scrollViewDidScroll(self.searchSuggestionsTableView)
            self.categorySelectionButtonHeightConstraint.constant = 0
            UIView.animate(withDuration: 0.3) {
                self.searchSuggestionsTableView.alpha = 1
            }
        })
    }

    @IBAction func searchEditingDidEnd(_ sender: UITextField) {
        UIView.animate(withDuration: 0.3, animations: {
            if (sender.text ?? "").isEmpty {
                self.magnifyingGlassImageView.image = #imageLiteral(resourceName: "search_field_icon")
                self.searchFieldLineWidthActiveConstraint.isActive = false
                self.searchFieldLineWidthInactiveConstraint.isActive = true
                self.searchFieldMagnifyingGlassLeadingSpaceConstraint.constant = 20
                self.searchFieldLineCenterXConstraint.constant = 0
                self.searchSuggestionsTableView.alpha = 0
                self.searchFilterButton.alpha = 0
                self.searchView.layoutIfNeeded()
            }
            SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        }, completion: { _ in
            if (sender.text ?? "").count == 0 {
                self.scrollViewDidScroll(self.categoriesCollectionView)
                self.categorySelectionButtonHeightConstraint.constant = 37
                UIView.animate(withDuration: 0.3) {
                    self.categoriesCollectionView.alpha = 1
                    self.categorySelectionButton.alpha = 1
                }
            }
        })
    }
    
    @IBAction func switchCategory(_ sender: UIButton) {
        categoriesCollectionView.setContentOffset(categoriesCollectionView.contentOffset, animated: false)
        productsCollectionView.setContentOffset(productsCollectionView.contentOffset, animated: false)
        categoriesDropdownView.alpha == 0 ? presentCategoriesDropdownPicker() : removeCategoriesDropdownPicker()
    }

    private func presentCategoriesDropdownPicker() {
        guard let snapshot = backgroundSnapshot, filtersView.alpha == 0 else { return }
        screenSnapshot = snapshot
        backgroundImageView.image = snapshot
        backgroundImageView.alpha = 1
        UIView.transition(with: backgroundImageView, duration: 0.15, options: .transitionCrossDissolve, animations: {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 0
            self.backgroundImageView.image = self.blurredSnapshot
        }, completion: { _ in
            self.whiteBackgroundColorView.alpha = 1
            UIView.animate(withDuration: 0.15) {
                self.backgroundImageView.alpha = 0.5
                self.snapshotBackgroundColorView.alpha = 0.5
                self.categoriesDropdownView.alpha = 1
            }
            UIView.transition(with: self.categorySelectionButton, duration: 0.3, options: .transitionCrossDissolve, animations: { self.categorySelectionButton.isSelected = true })
        })
    }

    private func removeCategoriesDropdownPicker() {
        UIView.animate(withDuration: 0.15, animations: {
            self.snapshotBackgroundColorView.alpha = 0
            self.categoriesDropdownView.alpha = 0
            self.whiteBackgroundColorView.alpha = 0
        }, completion: { _ in
            UIView.transition(with: self.backgroundImageView, duration: 0.15, options: .transitionCrossDissolve, animations: {
                SunriseTabBarController.currentlyActive?.tabView.alpha = 1
                self.backgroundImageView.image = self.backgroundSnapshot
            }, completion: { _ in
                self.backgroundImageView.image = nil
                self.backgroundImageView.alpha = 0
            })
            UIView.transition(with: self.categorySelectionButton, duration: 0.3, options: .transitionCrossDissolve, animations: { self.categorySelectionButton.isSelected = false })
        })
    }

    private func backToCategoryOverview() {
        isTransitioningToProducts = true
        UIView.animate(withDuration: 0.3, animations: {
            self.productsCollectionView.alpha = 0
            self.emptyStateView.alpha = 0
            self.filterButton.alpha = 0
            self.searchViewHeightConstraint.constant = 55
            self.view.layoutIfNeeded()
            self.searchField.text = ""
            self.searchEditingDidEnd(self.searchField)
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, animations: {
                self.searchView.alpha = 1
                self.categoriesCollectionView.alpha = 1
                self.checkAndPresentEmptyState()
            }, completion: { _ in
                [self.filterButton, self.searchFilterButton].forEach { $0.isSelected = false }
                self.isTransitioningToProducts = false
                self.updateBackgroundSnapshot()
            })
        })
    }

    private func checkAndPresentEmptyState() {
        guard !searchField.isFirstResponder, viewModel?.isLoading.value == false, viewModel?.productsViewModel.isLoading.value == false else {
            emptyStateView.alpha = 0
            return
        }
        let emptyStateAlpha: CGFloat = productsCollectionView.alpha == 1 ? (viewModel?.productsViewModel.numberOfProducts(in: 0) == 0 ? 1 : 0) : categoriesCollectionView.alpha == 1 && viewModel?.numberOfCategoryItems == 0 ? 1 : 0
        emptyStateView.alpha = emptyStateAlpha
    }

    private func updateFilterButtonSelectedState() {
        guard filtersView.alpha == 0 else { return }
        filterButton.isSelected = viewModel?.productsViewModel.filtersViewModel?.hasFiltersApplied == true
        searchFilterButton.isSelected = viewModel?.productsViewModel.filtersViewModel?.hasFiltersApplied == true
    }

    private func presentSearchResults() {
        UIView.animate(withDuration: 0.3, animations: {
            self.searchSuggestionsTableView.alpha = 0
        }, completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.productsCollectionView.alpha = 1
                self.checkAndPresentEmptyState()
                self.searchFilterButton.alpha = 1
                self.searchFieldLineWidthActiveConstraint.constant = -44
                self.searchFieldLineCenterXConstraint.constant = -22
                self.searchView.layoutIfNeeded()
            }
        })
    }

    private func presentProductOverview() {
        guard categoriesCollectionView.alpha == 1, !isTransitioningToProducts else { return }
        isTransitioningToProducts = true
        viewModel?.productsViewModel.clearProductsObserver.send(value: ())
        UIView.animate(withDuration: 0.3, animations: {
            self.searchView.alpha = 0
            self.categoriesCollectionView.alpha = 0
            self.searchViewHeightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, animations: {
                self.productsCollectionView.alpha = 1
                self.checkAndPresentEmptyState()
                self.filterButton.alpha = 1
            }, completion: { _ in
                self.isTransitioningToProducts = false
                self.updateBackgroundSnapshot()
            })
        })
    }

    // MARK: - Blurring effect

    private func updateBackgroundSnapshot() {
        guard let backgroundSnapshot = takeSnapshot() else { return }
        self.backgroundSnapshot = backgroundSnapshot
        blurredSnapshot = blur(image: backgroundSnapshot)
        if backgroundImageView.alpha > 0 {
            backgroundImageView.image = blurredSnapshot
        }
    }

    private func takeSnapshot() -> UIImage? {
        if let previousSnapshot = backgroundSnapshot,
           let visibleCollectionView = [categoriesCollectionView, productsCollectionView].filter({ $0.alpha == 1 }).first,
           backgroundImageView.alpha > 0 {
            UIGraphicsBeginImageContextWithOptions(visibleCollectionView.bounds.size, visibleCollectionView.isOpaque, 0.0)
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            let contentOffset = visibleCollectionView.contentOffset
            context.translateBy(x: -contentOffset.x, y: -contentOffset.y)
            visibleCollectionView.layer.render(in: context)
            let collectionSnapshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
            previousSnapshot.draw(in: view.bounds)
            collectionSnapshot?.draw(in: visibleCollectionView.frame)
            let updatedSnapshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return updatedSnapshot

        } else {
            guard let tabView = SunriseTabBarController.currentlyActive?.tabView else { return nil }
            UIGraphicsBeginImageContextWithOptions(tabView.bounds.size, tabView.isOpaque, 0.0)
            guard let context = UIGraphicsGetCurrentContext() else { return nil }
            tabView.layer.render(in: context)
            let tabSnapshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
            guard let newContext = UIGraphicsGetCurrentContext() else { return nil }
            view.layer.render(in: newContext)
            newContext.setFillColor(UIColor.white.cgColor)
            newContext.fill(categorySelectionButton.frame)
            tabSnapshot?.draw(in: CGRect(x: 0, y: tabView.frame.minY, width: view.bounds.width, height: tabView.bounds.height))
            let fullSnapshot = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return fullSnapshot
        }
    }
}

extension MainViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionView == categoriesCollectionView ? viewModel?.numberOfCategoryItems ?? 0 : viewModel?.productsViewModel.numberOfProducts(in: section) ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == categoriesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryCell", for: indexPath) as! CategoryCollectionViewCell
            cell.categoryNameLabel.text = viewModel?.categoryName(for: collectionView, at: indexPath)
            cell.categoryImageView.sd_setImage(with: URL(string: viewModel?.categoryImageUrl(at: indexPath) ?? ""))
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath) as! ProductOverviewCell
            guard let viewModel = viewModel?.productsViewModel else { return cell }
            cell.productNameLabel.text = viewModel.productName(at: indexPath)
            cell.productImageView.sd_setImage(with: URL(string: viewModel.productImageUrl(at: indexPath)))
            let oldPriceAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Bold", size: 12)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
            cell.oldPriceLabel.attributedText = NSAttributedString(string: viewModel.productOldPrice(at: indexPath), attributes: oldPriceAttributes)
            cell.priceLabel.text = viewModel.productPrice(at: indexPath)
            cell.priceLabel.textColor = viewModel.productOldPrice(at: indexPath).isEmpty ? UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0) : UIColor(red: 0.93, green: 0.26, blue: 0.26, alpha: 1.0)
            cell.wishListButton.isSelected = viewModel.isProductInWishList(at: indexPath)
            disposables += cell.wishListButton.reactive.controlEvents(.touchUpInside)
            .take(until: cell.reactive.prepareForReuse)
            .observeValues { [weak self] _ in
                cell.wishListButton.isSelected = !cell.wishListButton.isSelected
                self?.viewModel?.productsViewModel.toggleWishListObserver.send(value: indexPath)
            }
            return cell
        }
    }
}

extension MainViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView == categoriesCollectionView else { return }
        presentProductOverview()
        viewModel?.selectedCategoryCollectionItemObserver.send(value: indexPath)
    }
}

extension MainViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt sizeForItemAtIndexPath: IndexPath) -> CGSize {
        let screenWidth = view.bounds.size.width
        let cellWidth = (screenWidth - 30) / 2
        let cellHeight = collectionView == categoriesCollectionView ? 0.883 * cellWidth : productsCellHeight
        return CGSize(width: cellWidth, height: cellHeight)
    }
}

extension MainViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update gradient layer based on the scroll view content offset
        let yOffset = scrollView.contentOffset.y
        if 0...57 ~= yOffset {
            gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 13 + yOffset)
        } else if yOffset > 57 && gradientLayer.bounds.height < 70 {
            gradientLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 70)
        }

        guard let viewModel = viewModel?.productsViewModel else { return }

        if scrollView == productsCollectionView, viewModel.numberOfProducts(in: 0) > 0 {
            let bottomOfLastCell = scrollView.contentSize.height - scrollView.frame.height
            let topOfMiddleCell = scrollView.contentSize.height - scrollView.frame.height - CGFloat(viewModel.pageSize) * productsCellHeight / 4

            // Load new results when the y offset still hasn't reached the bottom.
            viewModel.hasReachedLowerHalfOfProducts.value = scrollView.contentOffset.y >= topOfMiddleCell

            // In case it did reach the bottom (i.e user scrolled fast), show the the progress as well.
            if scrollView.contentOffset.y >= bottomOfLastCell && viewModel.isLoading.value && !SVProgressHUD.isVisible() {
                SVProgressHUD.show()
            }
        }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate, (scrollView == categoriesCollectionView || scrollView == productsCollectionView) else { return }
        updateBackgroundSnapshot()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == categoriesCollectionView || scrollView == productsCollectionView else { return }
        updateBackgroundSnapshot()
    }
}

extension MainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == subcategoriesTableView ? viewModel?.numberOfCategoryRows ?? 0 : viewModel?.numberOfRecentSearches ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == searchSuggestionsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchSuggestion") as! SearchSuggestionCell
            cell.suggestionLabel.text = viewModel?.recentSearch(at: indexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell") as! CategoryTableViewCell
            let nameAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: viewModel?.isCategorySelected(at: indexPath) == true ? "Rubik-Medium" : "Rubik-Regular", size: 14)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)]
            cell.categoryNameLabel.attributedText = NSAttributedString(string: viewModel?.categoryName(for: tableView, at: indexPath) ?? "", attributes: nameAttributes)
            return cell
        }
    }
}

extension MainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == subcategoriesTableView {
            viewModel?.selectedCategoryTableRowObserver.send(value: indexPath)
        } else {
            searchField.text = viewModel?.recentSearch(at: indexPath)
            searchField.resignFirstResponder()
        }
    }
}

extension MainViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.productsViewModel.userLocation.value = locations.last
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint(error)
    }
}

extension UIViewController {
    func blur(image input: UIImage) -> UIImage? {
        guard let clampFilter = CIFilter(name: "CIAffineClamp"),
              let inputImage = CIImage(image: input) else  { return nil }
        clampFilter.setValue(inputImage, forKey: kCIInputImageKey)
        guard let blurFilter = CIFilter(name: "CIGaussianBlur"),
              let clampedImage = clampFilter.outputImage else { return nil }
        blurFilter.setValue(clampedImage, forKey: kCIInputImageKey)
        let context = CIContext(options:nil)
        guard let outputImage = blurFilter.outputImage,
              let outputCgImage = context.createCGImage(outputImage, from: inputImage.extent) else { return nil }
        return UIImage(cgImage: outputCgImage)
    }
}
