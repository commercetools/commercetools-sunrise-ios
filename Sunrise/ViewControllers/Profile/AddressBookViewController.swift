//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD

class AddressBookViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!

    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: AddressBookViewModel? {
        didSet {
            self.bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = AddressBookViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            if $0 {
                SVProgressHUD.show()
            } else {
                SVProgressHUD.dismiss()
                self.collectionView.reloadData()
            }
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.navigationController?.popViewController(animated: true)
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let addressViewController = segue.destination as? AddressViewController, let sender = sender as? UIButton else { return }
        _ = addressViewController.view
        if let cell = sender.superview?.superview as? AddressCell, let indexPath = collectionView.indexPath(for: cell), let viewModel = viewModel?.addressViewModelForAddress(at: indexPath) {
            addressViewController.viewModel = viewModel
        } else {
            addressViewController.viewModel = AddressViewModel(address: nil, type: .shipping)
        }
    }
}

extension AddressBookViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (viewModel?.numberOfAddresses ?? 0) + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < viewModel?.numberOfAddresses ?? 0 else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "AddNewCell", for: indexPath)
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AddressCell", for: indexPath) as! AddressCell
        guard let viewModel = viewModel else { return cell }
        cell.nameLabel.text = viewModel.addressName(at: indexPath)
        cell.detailsLabel.text = viewModel.addressDetails(at: indexPath)
        cell.defaultAddressLabel?.alpha = viewModel.isAddressDefault(at: indexPath) ? 1 : 0
        cell.makeDefaultAddressLabel?.alpha = viewModel.isAddressDefault(at: indexPath) ? 0 : 1
        cell.makeDefaultButton?.isSelected = viewModel.isAddressDefault(at: indexPath)
        disposables += cell.removeButton?.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in self?.viewModel?.deleteObserver.send(value: indexPath) }
        disposables += cell.makeDefaultButton?.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in self?.viewModel?.setDefaultAddressObserver.send(value: indexPath) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath)
        return headerView
    }
}

extension AddressBookViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt sizeForItemAtIndexPath: IndexPath) -> CGSize {
        let screenWidth = view.bounds.size.width
        return CGSize(width: screenWidth, height: 198)
    }
}
