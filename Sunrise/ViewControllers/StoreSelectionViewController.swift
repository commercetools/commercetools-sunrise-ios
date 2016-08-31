//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import CoreLocation
import ReactiveCocoa
import SVProgressHUD
import SDWebImage

class StoreSelectionViewController: UITableViewController {

    private let locationManager = CLLocationManager()

    var viewModel: StoreSelectionViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    private var reserveAction: CocoaAction?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 155
        tableView.tableFooterView = UIView()

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.startUpdatingLocation()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        navigationItem.title = viewModel.title

        reserveAction = CocoaAction(viewModel.reserveAction, { indexPath in return indexPath as! NSIndexPath })

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] isLoading in
            if !isLoading {
                self?.tableView.reloadData()
                SVProgressHUD.dismiss()
            } else {
                SVProgressHUD.show()
            }
        })

        viewModel.userLocation.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] _ in
            self?.tableView.reloadData()
        })

        viewModel.contentChangesSignal
        .observeOn(UIScheduler())
        .observeNext({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRowsAtIndexPaths(changeset.deletions, withRowAnimation: .Automatic)
            tableView.reloadRowsAtIndexPaths(changeset.modifications, withRowAnimation: .None)
            tableView.insertRowsAtIndexPaths(changeset.insertions, withRowAnimation: .Automatic)
            tableView.endUpdates()
        })

        viewModel.reserveAction.events
        .observeOn(UIScheduler())
        .observeNext({ [weak self] event in
            switch event {
            case .Completed:
                self?.presentSuccessfulReservationAlert()
            case let .Failed(error):
                let alertController = UIAlertController(
                        title: "Reservation failed",
                        message: self?.viewModel?.alertMessageForErrors([error]),
                        preferredStyle: .Alert
                        )
                alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
                self?.presentViewController(alertController, animated: true, completion: nil)
            default:
                return
            }
        })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsInSection(section) ?? 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("StoreDetailsCell") as! StoreDetailsCell
        guard let viewModel = viewModel else { return cell }

        if let expandedIndexPath = viewModel.channelDetailsIndexPath where indexPath == expandedIndexPath {
            let cell = tableView.dequeueReusableCellWithIdentifier("StoreInfoCell") as! StoreInfoCell
            cell.streetAndNumberLabel.text = viewModel.streetAndNumberInfo
            cell.zipAndCityLabel.text = viewModel.zipAndCityInfo
            cell.openLine1Label.text = viewModel.openingTimes

            return cell

        } else {
            cell.storeNameLabel.text = viewModel.storeNameAtIndexPath(indexPath)
            cell.storeDistanceLabel.text = viewModel.storeDistanceAtIndexPath(indexPath)
            cell.availabilityLabel.text = viewModel.availabilityAtIndexPath(indexPath)
            cell.expandInfoLabel.text = viewModel.expansionTextAtIndexPath(indexPath)
            cell.priceLabel.text = viewModel.priceForChannelAtIndexPath(indexPath)
            cell.availabilityIndicatorView.backgroundColor = viewModel.availabilityColorAtIndexPath(indexPath)
            cell.reserveButton.enabled = viewModel.reserveButtonEnabledAtIndexPath(indexPath)
            cell.reserveButton.alpha = viewModel.reserveButtonEnabledAtIndexPath(indexPath) ? 1.0 : 0.6
            cell.storeImageView.sd_setImageWithURL(NSURL(string: viewModel.storeImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        }
        return cell
    }

    // MARK: - Table view delegate

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        viewModel?.selectedIndexPathObserver.sendNext(indexPath)
    }
    
    // MARK: - Actions
    
    @IBAction func reserve(sender: UIButton) {
        let indexPath = self.tableView.indexPathForRowAtPoint(sender.convertPoint(.zero, toView: tableView))
        reserveAction?.execute(indexPath)
    }

    // MARK: - Success presentation

    private func presentSuccessfulReservationAlert() {
        let alertController = UIAlertController(
                title: viewModel?.reservationSuccessTitle,
                message: viewModel?.reservationSuccessMessage,
                preferredStyle: .Alert
                )
        alertController.addAction(UIAlertAction(title: viewModel?.reservationContinueTitle, style: .Default, handler: { [weak self] _ in
            self?.navigationController?.popToRootViewControllerAnimated(true)
        }))
        presentViewController(alertController, animated: true, completion: nil)
    }

}

extension StoreSelectionViewController: CLLocationManagerDelegate {

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }

}