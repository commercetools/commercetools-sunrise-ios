//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class MyStyleViewController: UIViewController {

    @IBOutlet weak var aToGBrandButton: UIButton!
    @IBOutlet weak var hToQBrandButton: UIButton!
    @IBOutlet weak var rToZBrandButton: UIButton!
    @IBOutlet weak var symbolBrandButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var genderSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var styleSettingsStackView: UIStackView!
    @IBOutlet weak var brandsCollectionView: UICollectionView!
    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: MyStyleViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        genderSegmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Rubik-Medium", size: 14)!, NSAttributedString.Key.foregroundColor: UIColor(red: 0.16, green: 0.20, blue: 0.25, alpha: 1.0)], for: .normal)
        genderSegmentedControl.setTitleTextAttributes([NSAttributedString.Key.font: UIFont(name: "Rubik-Medium", size: 14)!, NSAttributedString.Key.foregroundColor: UIColor.white], for: .selected)

        viewModel = MyStyleViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SunriseTabBarController.currentlyActive?.tabView.alpha = 0
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.tabView.alpha = 1
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }

    func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.signal
        .filter { !$0 }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            [self.brandsCollectionView, self.sizesCollectionView, self.colorsCollectionView].forEach { $0.reloadData() }
            if let visibleIndexPath = self.brandsCollectionView.indexPathForItem(at: self.brandsCollectionView.contentOffset) {
                self.viewModel?.visibleBrandIndex.value = visibleIndexPath
            }
            UIView.animate(withDuration: 0.3) {
                self.styleSettingsStackView.alpha = 1
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

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.navigationController?.popViewController(animated: true)
        }

        disposables += viewModel.scrollBrandAction.values
        .filter { $0 != nil }
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.brandsCollectionView.scrollToItem(at: $0!, at: .left, animated: true)
        }

        disposables += viewModel.saveSettingsAction.completed
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.navigationController?.popViewController(animated: true)
        }

        genderSegmentedControl.selectedSegmentIndex = viewModel.isWomen.value ? 0 : 1
        disposables += viewModel.isWomen <~ genderSegmentedControl.reactive.selectedSegmentIndexes.map { $0 == 0 }

        aToGBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 0 }
        hToQBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 1 }
        rToZBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 2 }
        symbolBrandButton.reactive.pressed = CocoaAction(viewModel.scrollBrandAction) { _ in return 3 }
        resetButton.reactive.pressed = CocoaAction(viewModel.resetSettingsAction)
        saveButton.reactive.pressed = CocoaAction(viewModel.saveSettingsAction)

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
}

extension MyStyleViewController: UICollectionViewDataSource {
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
            cell.selectedColorImageView.image = viewModel?.color(at: indexPath) != .white ? #imageLiteral(resourceName: "selected_color") : #imageLiteral(resourceName: "selected_color_inverted")
            cell.selectedColorImageView.isHidden = viewModel?.isColorActive(at: indexPath) == false
            return cell
        default:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductTypeCell", for: indexPath) as! ProductTypeCell
            cell.selectedProductImageView.isHidden = false
            return cell
        }
    }
}

extension MyStyleViewController: UICollectionViewDelegate {
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

extension MyStyleViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let visibleIndexPath = brandsCollectionView.indexPathForItem(at: scrollView.contentOffset), scrollView == brandsCollectionView {
            viewModel?.visibleBrandIndex.value = visibleIndexPath
        }
    }
}