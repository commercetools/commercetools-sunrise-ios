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

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 150

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()

        // TODO remove
        self.viewModel = StoreSelectionViewModel()
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

        if let expandedIndexPath = viewModel.expandedChannelIndexPath.value where indexPath == expandedIndexPath {
            let cell = tableView.dequeueReusableCellWithIdentifier("StoreInfoCell") as! StoreInfoCell
            // info cell details

        } else {
            cell.storeNameLabel.text = viewModel.storeNameAtIndexPath(indexPath)
            cell.storeDistanceLabel.text = viewModel.storeDistanceAtIndexPath(indexPath)
            cell.availabilityLabel.text = viewModel.availabilityAtIndexPath(indexPath)
            cell.expandInfoLabel.text = viewModel.expansionTextAtIndexPath(indexPath)
            cell.availabilityIndicatorView.backgroundColor = viewModel.availabilityColorAtIndexPath(indexPath)
            cell.storeImageView.sd_setImageWithURL(NSURL(string: viewModel.storeImageUrlAtIndexPath(indexPath)), placeholderImage: UIImage(named: "transparent"))

        }

        return cell
    }

}

extension StoreSelectionViewController: CLLocationManagerDelegate {

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }

}