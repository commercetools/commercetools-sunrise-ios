//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import MapKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class StoreSelectionViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var isOnStockImageView: UIImageView!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productColorView: UIView!

    @IBOutlet weak var wishlistButton: UIButton!
    @IBOutlet weak var reserveButton: UIButton!

    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var openHoursLabel: UILabel!
    @IBOutlet weak var storeAddressLabel: UILabel!
    @IBOutlet weak var isOnStockLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!

    private let locationManager = CLLocationManager()
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: StoreSelectionViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
    }

    override func viewDidDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewDidDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += productNameLabel.reactive.text <~ viewModel.productName
        disposables += distanceLabel.reactive.text <~ viewModel.distance
        disposables += storeNameLabel.reactive.text <~ viewModel.storeName
        disposables += openHoursLabel.reactive.text <~ viewModel.openingTimes
        disposables += storeAddressLabel.reactive.text <~ viewModel.storeAddress
        disposables += isOnStockLabel.reactive.attributedText <~ viewModel.isOnStock
        disposables += sizeLabel.reactive.text <~ viewModel.size
        disposables += quantityLabel.reactive.text <~ viewModel.quantity

        reserveButton.reactive.pressed = CocoaAction(viewModel.reserveAction)

        disposables += viewModel.isLoading.producer
        .observe(on: UIScheduler())
        .startWithValues { $0 ? SVProgressHUD.show() : SVProgressHUD.dismiss() }

        disposables += viewModel.productColor.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            self.productColorView.backgroundColor = $0
        }

        disposables += viewModel.productImageUrl.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            self.productImageView.sd_setImage(with: URL(string: $0))
        }

        disposables += viewModel.isOnStock.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            self.isOnStockImageView.image = $0?.string == self.viewModel?.onStock ? #imageLiteral(resourceName: "in_stock_checkmark") : #imageLiteral(resourceName: "not_available")
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
        .skipRepeats { $0 == $1 }
        .observe(on: UIScheduler())
        .filter { [weak self] selected in
            selected != nil && self?.mapView.selectedAnnotations.map({ $0.coordinate }).contains(selected!) == false
        }
        .startWithValues { [weak self] selected in
            self?.mapView.selectedAnnotations.forEach { self?.mapView.deselectAnnotation($0, animated: true) }
            if let selected = selected, let selectedAnnotation = self?.mapView.annotations.first(where: { $0.coordinate == selected }) {
                self?.mapView.selectAnnotation(selectedAnnotation, animated: true)
            }
        }

        disposables += viewModel.userLocation.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] userLocation in
            guard let mapView = self?.mapView else { return }
            if userLocation != nil {
                mapView.showsUserLocation = true
            }
        }

        disposables += viewModel.reserveAction.events
        .observe(on: UIScheduler())
        .observeValues({ [weak self] event in
            SVProgressHUD.dismiss()
            switch event {
                case .completed:
                    self?.performSegue(withIdentifier: "showConfirmation", sender: self)
                case let .failed(error):
                    let alertController = UIAlertController(
                            title: self?.viewModel?.failedTitle,
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

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let reservationConfirmationViewController = segue.destination as? ReservationConfirmationViewController {
            _ = reservationConfirmationViewController.view
            reservationConfirmationViewController.viewModel = viewModel?.reservationConfirmationViewModel
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

extension StoreSelectionViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint(error)
    }
}

extension StoreSelectionViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let isActive = viewModel?.selectedStoreCoordinate.value == annotation.coordinate
        let reuseIdentifier = isActive ? "activeStoreAnnotation" : "storeAnnotation"
        if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) {
            return annotationView
        }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        annotationView.image = isActive ? #imageLiteral(resourceName: "map_pin_active") : #imageLiteral(resourceName: "map_pin")
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
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}