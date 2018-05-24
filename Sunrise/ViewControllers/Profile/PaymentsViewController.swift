//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD

class PaymentsViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: PaymentsViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = PaymentsViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
        collectionView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.collectionView.reloadData()
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.navigationController?.popViewController(animated: true)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let paymentViewController = segue.destination as? PaymentViewController, let sender = sender as? UIButton else { return }
        _ = paymentViewController.view
        if let cell = sender.superview?.superview as? PaymentCell, let indexPath = collectionView.indexPath(for: cell), let viewModel = viewModel?.paymentViewModelForPayment(at: indexPath) {
            paymentViewController.viewModel = viewModel
        } else {
            paymentViewController.viewModel = PaymentViewModel()
        }
    }
}

extension PaymentsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (viewModel?.numberOfPayments ?? 0) + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < viewModel?.numberOfPayments ?? 0 else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: "AddNewCell", for: indexPath)
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaymentCell", for: indexPath) as! PaymentCell
        guard let viewModel = viewModel else { return cell }
        cell.last4DigitsLabel.text = viewModel.cardLast4Digits(at: indexPath)
        cell.nameLabel.text = viewModel.cardName(at: indexPath)
        cell.defaultPaymentLabel?.alpha = viewModel.isPaymentDefault(at: indexPath) ? 1 : 0
        cell.makeDefaultPaymentLabel?.alpha = viewModel.isPaymentDefault(at: indexPath) ? 0 : 1
        cell.makeDefaultButton?.isSelected = viewModel.isPaymentDefault(at: indexPath)
        disposables += cell.removeButton?.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in self?.viewModel?.deleteObserver.send(value: indexPath) }
        disposables += cell.makeDefaultButton?.reactive.controlEvents(.touchUpInside)
        .take(until: cell.reactive.prepareForReuse)
        .observeValues { [weak self] _ in self?.viewModel?.setDefaultPaymentObserver.send(value: indexPath) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath)
        return headerView
    }
}

extension PaymentsViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout: UICollectionViewLayout, sizeForItemAt sizeForItemAtIndexPath: IndexPath) -> CGSize {
        let screenWidth = view.bounds.size.width
        return CGSize(width: screenWidth, height: 198)
    }
}
