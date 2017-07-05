//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import CoreLocation
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD
import SDWebImage

class StoreSelectionViewController: UITableViewController {

    private let locationManager = CLLocationManager()

    var viewModel: StoreSelectionViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    private var reserveAction: CocoaAction<IndexPath>?
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 155
        tableView.tableFooterView = UIView()

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.startMonitoringSignificantLocationChanges()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopMonitoringSignificantLocationChanges()
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        navigationItem.title = viewModel.title

        reserveAction = CocoaAction(viewModel.reserveAction, { indexPath in return indexPath })

        viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues({ [weak self] isLoading in
            if !isLoading {
                self?.tableView.reloadData()
                self?.refreshControl?.endRefreshing()
                SVProgressHUD.dismiss()
            } else {
                SVProgressHUD.show()
            }
        })

        disposables += viewModel.contentChangesSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] changeset in
            guard let tableView = self?.tableView else { return }

            tableView.beginUpdates()
            tableView.deleteRows(at: changeset.deletions, with: .automatic)
            tableView.reloadRows(at: changeset.modifications, with: .none)
            tableView.insertRows(at: changeset.insertions, with: .automatic)
            tableView.endUpdates()
        })

        viewModel.reserveAction.events
        .observe(on: UIScheduler())
        .observeValues({ [weak self] event in
            switch event {
            case .value:
                self?.presentSuccessfulReservationAlert()
            case let .failed(error):
                let alertController = UIAlertController(
                        title: viewModel.failedTitle,
                        message: self?.viewModel?.alertMessage(for: [error]),
                        preferredStyle: .alert
                        )
                alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: nil))
                self?.present(alertController, animated: true, completion: nil)
            default:
                return
            }
        })

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRowsInSection(section) ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StoreDetailsCell") as! StoreDetailsCell
        guard let viewModel = viewModel else { return cell }

        if let expandedIndexPath = viewModel.channelDetailsIndexPath, indexPath == expandedIndexPath {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StoreInfoCell") as! StoreInfoCell
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
            cell.reserveButton.isEnabled = viewModel.reserveButtonEnabledAtIndexPath(indexPath)
            cell.reserveButton.alpha = viewModel.reserveButtonEnabledAtIndexPath(indexPath) ? 1.0 : 0.6
            cell.storeImageView.sd_setImage(with: URL(string: viewModel.storeImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        }
        return cell
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedIndexPathObserver.send(value: indexPath)
    }
    
    // MARK: - Actions
    
    @IBAction func reserve(_ sender: UIButton) {
        let indexPath = self.tableView.indexPathForRow(at: sender.convert(.zero, to: tableView))
        reserveAction?.execute(indexPath as AnyObject)
    }
    
    // MARK: - Refreshing
    
    @IBAction func refresh(_ sender: UIRefreshControl) {
        viewModel?.refreshObserver.send(value: ())
    }

    // MARK: - Success presentation

    private func presentSuccessfulReservationAlert() {
        let alertController = UIAlertController(
                title: viewModel?.reservationSuccessTitle,
                message: viewModel?.reservationSuccessMessage,
                preferredStyle: .alert
                )
        alertController.addAction(UIAlertAction(title: viewModel?.reservationContinueTitle, style: .default, handler: { [weak self] _ in
            _ = self?.navigationController?.popToRootViewController(animated: true)
        }))
        present(alertController, animated: true, completion: nil)
    }

}

extension StoreSelectionViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint(error)
    }
}
