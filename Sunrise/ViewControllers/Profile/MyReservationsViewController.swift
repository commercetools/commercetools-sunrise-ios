//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD

class MyReservationsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet var headerView: UIView!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: MyReservationsViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableHeaderView = headerView
        tableView.tableFooterView = UIView()
        viewModel = MyReservationsViewModel()
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
                self.tableView.reloadData()
                self.emptyStateView.alpha = self.viewModel?.numberOfReservations == 0 ? 1 : 0
            }
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
        if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell), let detailsViewController = segue.destination as? ReservationDetailsViewController {
            _ = detailsViewController.view
            detailsViewController.viewModel = viewModel?.reservationDetailsViewModelForOrder(at: indexPath)
        }
    }
}

extension MyReservationsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfReservations ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyReservationCell") as! MyReservationCell
        guard let viewModel = viewModel else { return cell }
        cell.reservationDate.text = viewModel.reservationDate(at: indexPath)
        cell.productImageView.sd_setImage(with: URL(string: viewModel.imageUrl(at: indexPath)), placeholderImage: UIImage(named: "transparent"))
        cell.productNameLabel.text = viewModel.productName(at: indexPath)
        cell.totalLabel.text = viewModel.totalPrice(at: indexPath)
        return cell
    }
}