//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveCocoa
import ReactiveSwift
import Result

class OrdersViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var myAccountHeader: UIView!
    @IBOutlet var myPreferencesHeader: UIView!
    @IBOutlet var myStoreView: UIView!
    
    var ordersHeader = Bundle.main.loadNibNamed("OrdersHeaderView", owner: nil, options: nil)?.first as! OrdersHeaderView

    var reservationsHeader = Bundle.main.loadNibNamed("OrdersHeaderView", owner: nil, options: nil)?.first as! OrdersHeaderView

    private let refreshControl = UIRefreshControl()

    var viewModel: OrdersViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = OrdersViewModel()
        tableView.tableFooterView = UIView()

        configureHeaderViews()

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        viewModel?.refreshObserver.send(value: ())
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            if !isLoading {
                self?.tableView.reloadData()
                self?.refreshControl.endRefreshing()
            } else {
                self?.refreshControl.beginRefreshing()
            }
        })

        viewModel.contentChangesSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRows(at: changeset.deletions, with: .automatic)
            tableView.reloadRows(at: changeset.modifications, with: .automatic)
            tableView.insertRows(at: changeset.insertions, with: .automatic)
            tableView.endUpdates()
        })

        viewModel.ordersExpanded.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] ordersExpanded in
            guard let ordersHeader = self?.ordersHeader else { return }
            ordersHeader.expansionIcon.image = UIImage(named: ordersExpanded ? "minus-icon" : "plus-icon")
            ordersHeader.backgroundColor = ordersExpanded ? ordersHeader.activeColor : ordersHeader.inactiveColor
            ordersHeader.columnDescriptionViewHidden = !ordersExpanded
            UIView.animate(withDuration: 0.3, animations: {
                ordersHeader.layoutIfNeeded()
            })

        })

        viewModel.reservationsExpanded.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] reservationsExpanded in
            guard let reservationsHeader = self?.reservationsHeader else { return }
            reservationsHeader.expansionIcon.image = UIImage(named: reservationsExpanded ? "minus-icon" : "plus-icon")
            reservationsHeader.backgroundColor = reservationsExpanded ? reservationsHeader.activeColor : reservationsHeader.inactiveColor
            reservationsHeader.columnDescriptionViewHidden = !reservationsExpanded
            UIView.animate(withDuration: 0.3, animations: {
                reservationsHeader.layoutIfNeeded()
            })
        })

        viewModel.showReservationSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] indexPath in
            self?.performSegue(withIdentifier: "reservationDetails", sender: indexPath)
        })

        observeAlertMessageSignal(viewModel: viewModel)

        viewModel.refreshObserver.send(value: ())
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let indexPath = sender as? IndexPath, let viewModel = viewModel else { return }

        if let orderOverviewViewController = segue.destination as? OrderOverviewViewController,
                let orderOverviewViewModel = viewModel.orderOverviewViewModelForOrderAtIndexPath(indexPath){
            orderOverviewViewController.viewModel = orderOverviewViewModel

        } else if let reservationViewController = segue.destination as? ReservationViewController,
                let reservationViewModel = viewModel.reservationViewModelForOrderAtIndexPath(indexPath){
            reservationViewController.viewModel = reservationViewModel
        }
    }

    // MARK: - Refreshing

    @objc private func refresh() {
        viewModel?.refreshObserver.send(value: ())
    }

    // MARK: - Headers configuration

    private func configureHeaderViews() {
        var recognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap))
        ordersHeader.addGestureRecognizer(recognizer)

        recognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap))
        reservationsHeader.addGestureRecognizer(recognizer)
    }

    func handleTap(_ recognizer: UITapGestureRecognizer) {
        if let headerView = recognizer.view, let viewModel = viewModel {
            viewModel.sectionExpandedObserver.send(value: headerView.tag)
        }
    }

    // MARK: - Logout action

    @IBAction func logout(_ sender: AnyObject) {
        viewModel?.logoutCustomer()
    }
}

// MARK: - UITableViewDataSource

extension OrdersViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OrderCell") as! OrderCell

        guard let viewModel = viewModel else { return cell }
        cell.orderNumberLabel.text = viewModel.orderNumberAtIndexPath(indexPath)
        cell.totalPriceLabel.text = viewModel.totalPriceAtIndexPath(indexPath)

        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsInSection(section) ?? 0
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

}

// MARK: - UITableViewDelegate

extension OrdersViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch section {
            case 0:
                return myAccountHeader
            case 3:
                return myPreferencesHeader
            case 4:
                return myStoreView
            default:
                let headerView = section == 1 ? ordersHeader : reservationsHeader
                guard let viewModel = viewModel else { return headerView }

                headerView.title.text = viewModel.headerTitleForSection(section)
                headerView.tag = section

                return headerView
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 25
        case 3:
            return 55
        default:
            return 80
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        indexPath.section == 0 ? performSegue(withIdentifier: "orderDetails", sender: indexPath) : performSegue(withIdentifier: "reservationDetails", sender: indexPath)
    }

}
