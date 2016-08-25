//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import Commercetools
import ReactiveCocoa
import Result

class OrdersViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    var ordersHeader = NSBundle.mainBundle().loadNibNamed("OrdersHeaderView", owner: nil, options: nil).first as! OrdersHeaderView

    var reservationsHeader = NSBundle.mainBundle().loadNibNamed("OrdersHeaderView", owner: nil, options: nil).first as! OrdersHeaderView

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

        refreshControl.addTarget(self, action: #selector(refresh), forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        viewModel?.refreshObserver.sendNext()
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] isLoading in
            if !isLoading {
                self?.tableView.reloadData()
                self?.refreshControl.endRefreshing()
            } else {
                self?.refreshControl.beginRefreshing()
            }
        })

        viewModel.contentChangesSignal
        .observeOn(UIScheduler())
        .observeNext({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRowsAtIndexPaths(changeset.deletions, withRowAnimation: .Automatic)
            tableView.reloadRowsAtIndexPaths(changeset.modifications, withRowAnimation: .Automatic)
            tableView.insertRowsAtIndexPaths(changeset.insertions, withRowAnimation: .Automatic)
            tableView.endUpdates()
        })

        viewModel.ordersExpanded.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] ordersExpanded in
            guard let ordersHeader = self?.ordersHeader else { return }
            ordersHeader.expansionIcon.image = UIImage(named: ordersExpanded ? "minus-icon" : "plus-icon")
            ordersHeader.backgroundColor = ordersExpanded ? ordersHeader.activeColor : ordersHeader.inactiveColor
            ordersHeader.columnDescriptionViewHidden = !ordersExpanded
            UIView.animateWithDuration(0.3, animations: {
                ordersHeader.layoutIfNeeded()
            })

        })

        viewModel.reservationsExpanded.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] reservationsExpanded in
            guard let reservationsHeader = self?.reservationsHeader else { return }
            reservationsHeader.expansionIcon.image = UIImage(named: reservationsExpanded ? "minus-icon" : "plus-icon")
            reservationsHeader.backgroundColor = reservationsExpanded ? reservationsHeader.activeColor : reservationsHeader.inactiveColor
            reservationsHeader.columnDescriptionViewHidden = !reservationsExpanded
            UIView.animateWithDuration(0.3, animations: {
                reservationsHeader.layoutIfNeeded()
            })
        })

        viewModel.showReservationSignal
        .observeOn(UIScheduler())
        .observeNext({ [weak self] indexPath in
            self?.performSegueWithIdentifier("reservationDetails", sender: indexPath)
        })

        observeAlertMessageSignal(viewModel: viewModel)

        viewModel.refreshObserver.sendNext()
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard let indexPath = sender as? NSIndexPath, viewModel = viewModel else { return }

        if let orderOverviewViewController = segue.destinationViewController as? OrderOverviewViewController,
                orderOverviewViewModel = viewModel.orderOverviewViewModelForOrderAtIndexPath(indexPath){
            orderOverviewViewController.viewModel = orderOverviewViewModel

        } else if let reservationViewController = segue.destinationViewController as? ReservationViewController,
                reservationViewModel = viewModel.reservationViewModelForOrderAtIndexPath(indexPath){
            reservationViewController.viewModel = reservationViewModel
        }
    }

    // MARK: - Refreshing

    @objc private func refresh() {
        viewModel?.refreshObserver.sendNext()
    }

    // MARK: - Headers configuration

    private func configureHeaderViews() {
        var recognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap))
        ordersHeader.addGestureRecognizer(recognizer)

        recognizer = UITapGestureRecognizer(target: self, action:#selector(handleTap))
        reservationsHeader.addGestureRecognizer(recognizer)
    }

    func handleTap(recognizer: UITapGestureRecognizer) {
        if let headerView = recognizer.view, viewModel = viewModel {
            viewModel.sectionExpandedObserver.sendNext(headerView.tag)
        }
    }

    // MARK: - Logout action

    @IBAction func logout(sender: AnyObject) {
        // Temporary perform login in view controller, refactor once orders are in place
        NSUserDefaults.standardUserDefaults().setObject(nil, forKey: kLoggedInUsername)
        NSUserDefaults.standardUserDefaults().synchronize()
        AuthManager.sharedInstance.logoutUser()
        AppRouting.setupMyAccountRootViewController(isLoggedIn: false)
    }


}

// MARK: - UITableViewDataSource

extension OrdersViewController: UITableViewDataSource {

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("OrderCell") as! OrderCell

        guard let viewModel = viewModel else { return cell }
        cell.orderNumberLabel.text = viewModel.orderNumberAtIndexPath(indexPath)
        cell.totalPriceLabel.text = viewModel.totalPriceAtIndexPath(indexPath)

        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsInSection(section) ?? 0
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

}

// MARK: - UITableViewDelegate

extension OrdersViewController: UITableViewDelegate {

    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = section == 0 ? ordersHeader : reservationsHeader
        guard let viewModel = viewModel else { return headerView }

        headerView.title.text = viewModel.headerTitleForSection(section)
        headerView.tag = section

        return headerView
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        indexPath.section == 0 ? performSegueWithIdentifier("orderDetails", sender: indexPath) : performSegueWithIdentifier("reservationDetails", sender: indexPath)
    }

}
