//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import ReactiveCocoa
import ReactiveSwift
import SVProgressHUD

class StoreFinderViewController: UIViewController {
    
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var storeDetailsView: UIScrollView!
    @IBOutlet weak var magnifyingGlassImageView: UIImageView!

    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var setAsDefaultStoreButton: UIButton!
    @IBOutlet weak var selectedStoreNameLabel: UILabel!
    @IBOutlet weak var selectedStoreDistanceLabel: UILabel!
    @IBOutlet weak var selectedStoreAddressLabel: UILabel!
    @IBOutlet weak var selectedStoreOpenHoursLabel: UILabel!
    

    @IBOutlet weak var searchFieldMagnifyingGlassLeadingSpaceConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchFieldLineCenterXConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthActiveConstraint: NSLayoutConstraint!
    @IBOutlet var searchFieldLineWidthInactiveConstraint: NSLayoutConstraint!

    private var isUpdatingAnnotations = false
    private let locationManager = CLLocationManager()
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: StoreFinderViewModel? {
        didSet {
            self.bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        let placeholderAttributes: [NSAttributedStringKey : Any] = [.font: UIFont(name: "Rubik-Light", size: 14)!, .foregroundColor: UIColor(red: 0.34, green: 0.37, blue: 0.40, alpha: 1.0)]
        searchField.attributedPlaceholder = NSAttributedString(string: NSLocalizedString("search", comment: "search"), attributes: placeholderAttributes)

        viewModel = StoreFinderViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
    }

    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.textSearch <~ searchField.reactive.continuousTextValues
        disposables += selectedStoreNameLabel.reactive.text <~ viewModel.selectedStoreName
        disposables += selectedStoreDistanceLabel.reactive.text <~ viewModel.selectedStoreDistance
        disposables += selectedStoreAddressLabel.reactive.text <~ viewModel.selectedStoreAddress
        disposables += selectedStoreOpenHoursLabel.reactive.text <~ viewModel.selectedStoreOpenHours
        disposables += setAsDefaultStoreButton.reactive.isSelected <~ viewModel.isSelectedStoreDefault

        setAsDefaultStoreButton.reactive.pressed = CocoaAction(viewModel.setAsDefaultStoreAction)

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            if $0 {
                SVProgressHUD.show()
            } else {
                self.tableView.reloadData()
                SVProgressHUD.dismiss()
            }
        }

        disposables += viewModel.isStoreDetailsVisible.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] isStoreDetailsVisible in
            UIView.animate(withDuration: 0.3) {
                self.storeDetailsView.alpha = isStoreDetailsVisible ? 1 : 0
                self.tableView.alpha = isStoreDetailsVisible ? 0 : 1
            }
        }

        disposables += viewModel.storeLocations.producer
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

        disposables += viewModel.visibleMapRect.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] visibleRegion in
            self?.mapView.setVisibleMapRect(visibleRegion, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
        }

        disposables += viewModel.selectedStoreCoordinate.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] selectedStoreCoordinate in
            self.isUpdatingAnnotations = true
            self.mapView.selectedAnnotations.forEach { self.mapView.deselectAnnotation($0, animated: true) }
            guard let annotation = self.mapView.annotations.first(where: { $0.coordinate == selectedStoreCoordinate }) else { return }
            self.mapView.selectAnnotation(annotation, animated: true)
            self.isUpdatingAnnotations = false
        }

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            if self.viewModel?.isStoreDetailsVisible.value == true {
                self.viewModel?.isStoreDetailsVisible.value = false
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }

        disposables += observeAlertMessageSignal(viewModel: viewModel)
    }

    @IBAction func searchEditingDidBegin(_ sender: UITextField) {
        UIView.animate(withDuration: 0.3) {
            self.magnifyingGlassImageView.image = #imageLiteral(resourceName: "search_field_icon_active")
            self.searchFieldMagnifyingGlassLeadingSpaceConstraint.constant = 0
            self.searchFieldLineCenterXConstraint.constant = 0
            self.searchFieldLineWidthInactiveConstraint.isActive = false
            self.searchFieldLineWidthActiveConstraint.isActive = true
            self.searchFieldLineWidthActiveConstraint.constant = 0
            self.searchView.layoutIfNeeded()
        }
    }

    @IBAction func searchEditingDidEnd(_ sender: UITextField) {
        UIView.animate(withDuration: 0.3) {
            if (sender.text ?? "").isEmpty {
                self.magnifyingGlassImageView.image = #imageLiteral(resourceName: "search_field_icon")
                self.searchFieldLineWidthActiveConstraint.isActive = false
                self.searchFieldLineWidthInactiveConstraint.isActive = true
                self.searchFieldMagnifyingGlassLeadingSpaceConstraint.constant = 20
                self.searchFieldLineCenterXConstraint.constant = 0
                self.searchView.layoutIfNeeded()
            }
        }
    }

    // MARK: - Map zoom

    @IBAction func zoomIn(_ sender: UIButton) {
        mapView.setVisibleMapRect(mapView.visibleMapRect, edgePadding: UIEdgeInsets(top: -210, left: -210, bottom: -210, right: -210), animated: true)
    }

    @IBAction func zoomOut(_ sender: UIButton) {
        mapView.setVisibleMapRect(mapView.visibleMapRect, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
    }
}

extension StoreFinderViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfStores ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "StoreCell") as! StoreCell
        guard let viewModel = viewModel else { return cell }
        cell.pinImageView.image = viewModel.isSelected(at: indexPath) ? #imageLiteral(resourceName: "store_finder_active_cell_pin") : #imageLiteral(resourceName: "store_finder_default_cell_pin")
        cell.accessoryImageView.isHidden = !viewModel.isSelected(at: indexPath)
        cell.addressLabel.text = viewModel.address(at: indexPath)
        cell.distanceLabel.text = viewModel.distance(at: indexPath)
        cell.distanceLabel.textColor = viewModel.isSelected(at: indexPath) ? UIColor(red: 1.00, green: 0.51, blue: 0.33, alpha: 1.0) : UIColor(red: 0.05, green: 0.62, blue: 0.97, alpha: 1.0)
        return cell
    }
}

extension StoreFinderViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedStoreObserver.send(value: indexPath)
    }
}

extension StoreFinderViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let reuseIdentifier = "storeAnnotation"
        if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) {
            return annotationView
        }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        annotationView.image = #imageLiteral(resourceName: "map_pin")
        return annotationView
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard !(view.annotation is MKUserLocation) else { return }
        view.image = #imageLiteral(resourceName: "map_pin_active")
        guard viewModel?.selectedStoreCoordinate.value != view.annotation?.coordinate else { return }
        viewModel?.selectedStoreCoordinate.value = view.annotation?.coordinate
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        view.image = #imageLiteral(resourceName: "map_pin")
        guard !isUpdatingAnnotations else { return }
        viewModel?.deselectedStoreObserver.send(value: ())
    }
}

extension StoreFinderViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint(error)
    }
}
