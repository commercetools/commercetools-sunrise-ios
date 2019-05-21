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
    @IBOutlet weak var voiceSearchView: UIView!
    @IBOutlet weak var imageSearchView: UIView!
    @IBOutlet weak var gradientView: UIView!
    @IBOutlet weak var categoriesDropdownGradientView: UIView!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var categoriesDropdownView: UIView!
    @IBOutlet weak var emptyStateView: UIScrollView!
    @IBOutlet weak var categoriesCollectionView: UICollectionView!
    @IBOutlet weak var productsCollectionView: UICollectionView!
    @IBOutlet weak var searchSuggestionsTableView: UITableView!
    @IBOutlet weak var subcategoriesTableView: UITableView!
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
    @IBOutlet weak var voiceSearchButton: UIButton!
    @IBOutlet weak var imageSearchButton: UIButton!
    @IBOutlet weak var expandSearchButton: UIButton!

    @IBOutlet weak var searchViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var collectionViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var categorySelectionButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldLineCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var categoriesDropdownCenterXConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFilterBackgroundTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var filterBackgroundTopConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthActiveConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthInactiveConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldLineLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldLineTrailingConstraint: NSLayoutConstraint!

    private weak var filtersViewController: FiltersViewController?
    private weak var voiceSearchViewController: VoiceSearchViewController?
    private weak var imageSearchViewController: ImageSearchViewController?
    private let clearSearchButton = UIButton(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
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
        subcategoriesTableView.contentInset = UIEdgeInsets(top: 17, left: 0, bottom: 0, right: 0)

        let placeholderAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red: 0.34, green: 0.37, blue: 0.40, alpha: 1.0)]
        searchField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("search", comment: "search"), attributes: placeholderAttributes)

        [searchSuggestionsTableView, subcategoriesTableView].forEach { $0.tableFooterView = UIView() }
        subcategoriesTableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: subcategoriesTableView.bounds.width, height: 0.5))
        subcategoriesTableView.tableHeaderView?.backgroundColor = subcategoriesTableView.separatorColor

        clearSearchButton.setImage(#imageLiteral(resourceName: "clear-button"), for: .normal)
        searchField.rightViewMode = .whileEditing
        searchField.rightView = clearSearchButton

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
            SunriseTabBarController.currentlyActive?.backButton.alpha = 1
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
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
        .observeValues { [unowned self] _ in
            self.backToCategoryOverview()
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            if self.categoriesDropdownView.alpha == 1 {
                self.switchCategory(self.categorySelectionButton)

            } else if self.filtersView.alpha == 1 {
                self.filtersViewController?.closeFilters()

            } else if self.searchField.isFirstResponder {
                self.searchField.text = ""
                self.searchField.resignFirstResponder()

            } else {
                NotificationCenter.default.post(name: Foundation.Notification.Name.Navigation.resetSearch, object: nil, userInfo: nil)
            }
        }

        disposables += searchField.reactive.textValues
        .filter { $0 != "" }
        .observeValues { [weak self] _ in
            self?.presentSearchResults()
        }

        disposables += searchField.reactive.continuousTextValues
        .observeValues { [weak self] in
            self?.searchField.rightView?.alpha = $0 == "" ? 0 : 1
        }

        disposables += clearSearchButton.reactive.controlEvents(.touchUpInside)
        .observeValues { [weak self] _ in
            self?.searchField.text = ""
        }

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss() }

        disposables += observeAlertMessageSignal(viewModel: viewModel)

        viewModel.voiceSearchViewModel = voiceSearchViewController?.viewModel
        viewModel.imageSearchViewModel = imageSearchViewController?.viewModel

        bindProductsViewModel()
        bindFiltersViewModel()
        bindVoiceSearchViewModel()
        bindImageSearchViewModel()
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
        
        disposables += viewModel.isLoading.producer
        .filter { $0 }
        .delay(0.3, on: QueueScheduler())
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            if self.viewModel?.productsViewModel.isLoading.value == true, self.filtersView.alpha == 0 {
                SVProgressHUD.show()
            }
        }

        disposables += viewModel.textSearch <~ searchField.reactive.textValues.map { ($0, Locale.current) }

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

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    func bindFiltersViewModel() {
        guard let viewModel = viewModel?.productsViewModel.filtersViewModel, filtersViewController?.isViewLoaded == true else { return }

        disposables += viewModel.isMyStyleApplied.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            switch ($0, self.filterButton.alpha == 1) {
                case (true, true):
                    self.filterMyStyleAppliedImageView.alpha = 1
                    self.searchFilterMyStyleAppliedImageView.alpha = 0
                case (true, false):
                    self.filterMyStyleAppliedImageView.alpha = 0
                    self.searchFilterMyStyleAppliedImageView.alpha = 1
                case (false, _):
                    [self.filterMyStyleAppliedImageView, self.searchFilterMyStyleAppliedImageView].forEach { $0.alpha = 0 }
            }
        }
        
        disposables += viewModel.isLoading.producer
        .filter { $0 }
        .delay(0.5, on: QueueScheduler())
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            if self.viewModel?.productsViewModel.filtersViewModel?.isLoading.value == true {
                SVProgressHUD.show()
            }
        }

        disposables += viewModel.isLoading.producer
        .filter { $0 }
        .delay(0.5, on: QueueScheduler())
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            if self.viewModel?.productsViewModel.filtersViewModel?.isLoading.value == true {
                SVProgressHUD.show()
            }
        }

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { _ in SVProgressHUD.dismiss() }
    }
    
    func bindVoiceSearchViewModel() {
        guard let viewModel = viewModel?.voiceSearchViewModel, voiceSearchViewController?.isViewLoaded == true, isViewLoaded else { return }
        
        disposables += voiceSearchButton.reactive.isSelected <~ viewModel.isRecognitionInProgress
        disposables += viewModel.performSearchSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] searchParams in
            self.categorySelectionButton.alpha = 0
            self.categorySelectionButtonHeightConstraint.constant = 0
            [self.productsCollectionView, self.categoriesCollectionView].forEach { $0?.alpha = 0 }
            self.searchField.text = searchParams.0
            self.viewModel?.productsViewModel.textSearch.value = searchParams
            self.searchEditingDidEnd(self.searchField)
            self.presentSearchResults()
        }
        
        disposables += viewModel.dismissSignal
        .filter { [unowned self] in self.voiceSearchView.alpha == 1 }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            UIView.animate(withDuration: 0.3) {
                self.voiceSearchView.alpha = 0
                SunriseTabBarController.currentlyActive?.tabView.alpha = 1
                guard self.productsCollectionView.alpha == 1 else { return }
                self.updateFilterButton(isHidden: false)
            }
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: UIApplication.didBecomeActiveNotification)
        .combineLatest(with: viewModel.isRecognitionInProgress.signal)
        .filter { $1 }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            self.presentVoiceSearchView()
        }

        disposables += viewModel.startSpeechRecognitionSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.presentVoiceSearchView()
        }
    }

    func bindImageSearchViewModel() {
        guard let viewModel = viewModel?.imageSearchViewModel, imageSearchViewController?.isViewLoaded == true, isViewLoaded else { return }

        disposables += viewModel.dismissSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            UIView.animate(withDuration: 0.3) {
                self.imageSearchView.alpha = 0
                self.imageSearchButton.isSelected = false
                SunriseTabBarController.currentlyActive?.tabView.alpha = 1
                guard self.productsCollectionView.alpha == 1 else { return }
                self.updateFilterButton(isHidden: false)
            }
        }
    }

    private func presentVoiceSearchView() {
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 0
            self.voiceSearchView.alpha = 1
            self.updateFilterButton(isHidden: true)
        }
    }

    private func presentImageSearchView() {
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.tabView.alpha = 0
            self.imageSearchView.alpha = 1
            self.updateFilterButton(isHidden: true)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.destination {
            case let filtersViewController as FiltersViewController:
                self.filtersViewController = filtersViewController
                _ = filtersViewController.view
            case let recommendationsViewController as InlineProductOverviewViewController:
                _ = recommendationsViewController.view
                recommendationsViewController.viewModel = CartViewModel.recommendationsViewModel
            case let detailsViewController as ProductDetailsViewController:
                _ = detailsViewController.view
                if let cell = sender as? UICollectionViewCell, let indexPath = productsCollectionView.indexPath(for: cell) {
                    detailsViewController.viewModel = viewModel?.productsViewModel.productDetailsViewModelForProduct(at: indexPath)
                } else if let viewModel = sender as? ProductDetailsViewModel {
                    detailsViewController.viewModel = viewModel
                }
            case let voiceSearchViewController as VoiceSearchViewController:
                self.voiceSearchViewController = voiceSearchViewController
                _ = voiceSearchViewController.view
            case let imageSearchViewController as ImageSearchViewController:
                self.imageSearchViewController = imageSearchViewController
                _ = imageSearchViewController.view
            default:
                return
        }
    }

    @IBAction func searchFilter(_ sender: UIButton) {
        UIApplication.shared.beginIgnoringInteractionEvents()
        if filtersView.alpha == 1 {
            UIView.animate(withDuration: 0.3, animations: {
                self.searchFilterBackgroundTopImageView.alpha = 0
                self.filtersView.alpha = 0
                SunriseTabBarController.currentlyActive?.tabView.alpha = 1
            }, completion: { _ in
                UIApplication.shared.endIgnoringInteractionEvents()
                if self.viewModel?.productsViewModel.isLoading.value == true {
                    SVProgressHUD.show()
                }
            })
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
    
    @IBAction func voiceSearch(_ sender: UIButton) {
        searchField.resignFirstResponder()
        if imageSearchButton.isSelected {
            imageSearch(imageSearchButton)
        }
        if sender.isSelected {
            viewModel?.voiceSearchViewModel?.dismissObserver.send(value: ())
        } else {
            viewModel?.voiceSearchViewModel?.startSpeechRecognitionObserver.send(value: ())
        }
    }


    @IBAction func imageSearch(_ sender: UIButton) {
        searchField.resignFirstResponder()
        if voiceSearchButton.isSelected {
            voiceSearch(voiceSearchButton)
        }
        if sender.isSelected {
            viewModel?.imageSearchViewModel?.dismissObserver.send(value: ())
        } else {
            sender.isSelected = !sender.isSelected
            viewModel?.imageSearchViewModel?.resetImageSelectionObserver.send(value: ())
            presentImageSearchView()
        }
    }
    
    @IBAction func searchEditingDidBegin(_ sender: UITextField) {
        viewModel?.productsViewModel.clearProductsObserver.send(value: ())
        viewModel?.voiceSearchViewModel?.dismissObserver.send(value: ())
        viewModel?.imageSearchViewModel?.dismissObserver.send(value: ())
        UIView.animate(withDuration: 0.3, animations: {
            self.checkAndPresentEmptyState()
            self.categorySelectionButton.alpha = 0
            SunriseTabBarController.currentlyActive?.backButton.alpha = 1
            self.searchFieldLineLeadingConstraint.constant = 54
            self.updateFilterButton(isHidden: true)
            self.expandSearchButton.alpha = 1
            [self.productsCollectionView, self.categoriesCollectionView, self.voiceSearchButton, self.imageSearchButton].forEach { $0?.alpha = 0 }
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
                self.searchFieldLineLeadingConstraint.constant = 108
                self.searchFieldLineTrailingConstraint.constant = 10
                [self.voiceSearchButton, self.imageSearchButton].forEach { $0?.alpha = 1 }
                self.expandSearchButton.alpha = 0
                self.searchSuggestionsTableView.alpha = 0
                self.searchFilterButton.alpha = 0
                self.searchView.layoutIfNeeded()
            }
            SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        }, completion: { _ in
            if (sender.text ?? "").count == 0 {
                self.scrollViewDidScroll(self.categoriesCollectionView)
                self.categorySelectionButtonHeightConstraint.constant = 37
                UIView.animate(withDuration: 0.3, animations: {
                    self.categoriesCollectionView.alpha = 1
                    self.categorySelectionButton.alpha = 1
                }, completion: { _ in
                    self.updateBackgroundSnapshot()
                })
            }
        })
    }

    @IBAction func expandSearch(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3, animations: {
            sender.alpha = 0
            self.searchFieldLineLeadingConstraint.constant = 108
            self.searchView.layoutIfNeeded()
        }, completion: { _ in
            UIView.animate(withDuration: 0.3) {
                [self.voiceSearchButton, self.imageSearchButton].forEach { $0?.alpha = 1 }
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
            [self.filterMyStyleAppliedImageView, self.searchFilterMyStyleAppliedImageView].forEach { $0.alpha = 0 }
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

    private func updateFilterButton(isHidden: Bool) {
        searchFilterButton.alpha = isHidden ? 0 : 1
        searchFieldLineTrailingConstraint.constant = isHidden ? 10 : 59
        self.searchView.layoutIfNeeded()
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
            self.voiceSearchView.alpha = 0
            SunriseTabBarController.currentlyActive?.tabView.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.productsCollectionView.alpha = 1
                self.checkAndPresentEmptyState()
                self.updateFilterButton(isHidden: false)
                SunriseTabBarController.currentlyActive?.backButton.alpha = 1
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
                SunriseTabBarController.currentlyActive?.backButton.alpha = 1
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
            let oldPriceAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: "Rubik-Bold", size: 12)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0), .strikethroughStyle: 1]
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
            let nameAttributes: [NSAttributedString.Key : Any] = [.font: UIFont(name: viewModel?.isCategorySelected(at: indexPath) == true ? "Rubik-Medium" : "Rubik-Regular", size: 14)!, .foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)]
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
