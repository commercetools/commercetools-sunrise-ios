//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD
import SDWebImage

class MyStoreViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var selectedStoreDetailsView: UIView!
    @IBOutlet weak var selectedStoreViewBottomGuide: NSLayoutConstraint!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var streetAndNumberLabel: UILabel!
    @IBOutlet weak var zipAndCityLabel: UILabel!
    @IBOutlet weak var openLine1Label: UILabel!
    @IBOutlet weak var tableViewHeight: NSLayoutConstraint!

    private let locationManager = CLLocationManager()
    private let refreshControl = UIRefreshControl()

    var viewModel: MyStoreViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
        tableView.tableFooterView = UIView()
        tableViewHeight.constant = 0.55 * view.bounds.size.height

        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()

        viewModel = MyStoreViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        locationManager.startUpdatingLocation()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        storeNameLabel.reactive.text <~ viewModel.selectedStoreName
        streetAndNumberLabel.reactive.text <~ viewModel.selectedStreetAndNumberInfo
        zipAndCityLabel.reactive.text <~ viewModel.selectedZipAndCityInfo
        openLine1Label.reactive.text <~ viewModel.selectedOpenLine1Info

        viewModel.isLoading.producer
                .observe(on: UIScheduler())
                .startWithValues({ [weak self] isLoading in
                    if !isLoading {
                        self?.tableView.reloadData()
                        self?.refreshControl.endRefreshing()
                        SVProgressHUD.dismiss()
                    } else {
                        SVProgressHUD.show()
                    }
                })

        viewModel.userLocation.producer
                .observe(on: UIScheduler())
                .startWithValues{ [weak self] _ in
                    self?.tableView.reloadData()
                }

        viewModel.storeLocations.producer
                .observe(on: UIScheduler())
                .startWithValues { [weak self] storeLocations in
                    guard let mapView = self?.mapView else { return }
                    mapView.removeAnnotations(mapView.annotations)
                    storeLocations.forEach { storeLocation in
                        let storeAnnotation =  MKPointAnnotation()
                        storeAnnotation.coordinate = storeLocation.coordinate
                        mapView.addAnnotation(storeAnnotation)
                    }
                }

        viewModel.visibleMapRect.producer
                .observe(on: UIScheduler())
                .startWithValues { [weak self] visibleRegion in
                    self?.mapView.setVisibleMapRect(visibleRegion, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
                }

        viewModel.userLocation.producer
                .observe(on: UIScheduler())
                .startWithValues { [weak self] userLocation in
                    guard let mapView = self?.mapView else { return }
                    if userLocation != nil {
                        mapView.showsUserLocation = true
                    }
                }

        viewModel.selectedStoreLocation.producer
                .observe(on: UIScheduler())
                .startWithValues({ [weak self] storeLocation in
                    guard let view = self?.view, let mapView = self?.mapView,
                          let tableViewHeight = self?.tableViewHeight,
                          let selectedStoreDetailsView = self?.selectedStoreDetailsView,
                          let selectedStoreViewBottomGuide = self?.selectedStoreViewBottomGuide else { return }
                    if let storeLocation = storeLocation {
                        let mapViewRegion = MKCoordinateRegion(center: storeLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        mapView.setRegion(mapViewRegion, animated: true)
                    }
                    self?.navigationItem.rightBarButtonItem = storeLocation != nil ? UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self?.closeStoreDetails)) : nil
                    self?.navigationItem.hidesBackButton = storeLocation != nil
                    UIView.animate(withDuration: 0.5) {
                        tableViewHeight.constant = storeLocation != nil ? 0 : 0.55 * view.bounds.size.height
                        selectedStoreViewBottomGuide.constant = storeLocation != nil ? 0 : -selectedStoreDetailsView.bounds.size.height
                        view.layoutIfNeeded()
                    }
                })

        observeAlertMessageSignal(viewModel: viewModel)
    }

    @objc private func closeStoreDetails() {
        viewModel?.selectedIndexPathObserver.send(value: nil)
    }

    // MARK: - Refreshing

    @IBAction func refresh(_ sender: UIRefreshControl) {
        viewModel?.refreshObserver.send(value: ())
    }
}

extension MyStoreViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfRows(in: section) ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StoreDetailsCell") as! StoreDetailsCell
        guard let viewModel = viewModel else { return cell }

        cell.storeNameLabel.text = viewModel.storeName(at: indexPath)
        cell.storeDistanceLabel.text = viewModel.storeDistance(at: indexPath)
        cell.storeImageView.sd_setImage(with: URL(string: viewModel.storeImageUrl(at: indexPath)), placeholderImage: UIImage(named: "transparent"))
        cell.accessoryType = viewModel.isMyStore(at: indexPath) ? .checkmark : .none

        return cell
    }
}

extension MyStoreViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedIndexPathObserver.send(value: indexPath)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension MyStoreViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }
}
