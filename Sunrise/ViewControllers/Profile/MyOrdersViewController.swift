//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD

class MyOrdersViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyStateView: UIView!
    @IBOutlet var headerView: UIView!
    
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: MyOrdersViewModel? {
        didSet {
            self.bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableHeaderView = headerView
        tableView.tableFooterView = UIView()
        viewModel = MyOrdersViewModel()
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
                self.emptyStateView.alpha = self.viewModel?.numberOfOrders == 0 ? 1 : 0
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
        if let cell = sender as? UITableViewCell, let indexPath = tableView.indexPath(for: cell), let detailsViewController = segue.destination as? OrderDetailsViewController {
            _ = detailsViewController.view
            detailsViewController.viewModel = viewModel?.orderDetailsViewModelForOrder(at: indexPath)
        }
    }

    @IBAction func continueShopping(_ sender: UIButton) {
        AppRouting.showMainTab()
    }
}

extension MyOrdersViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfOrders ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OrderCell") as! OrderCell
        guard let viewModel = viewModel else { return cell }
        cell.createdLabel.text = viewModel.created(at: indexPath)
        cell.orderNumberLabel.text = viewModel.orderNumber(at: indexPath)
        cell.totalPriceLabel.text = viewModel.totalPrice(at: indexPath)
        return cell
    }
}
