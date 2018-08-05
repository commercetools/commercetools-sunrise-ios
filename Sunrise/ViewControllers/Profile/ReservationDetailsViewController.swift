//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import MapKit
import ReactiveCocoa
import ReactiveSwift

class ReservationDetailsViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var productImageView: UIImageView!
    
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var createdLabel: UILabel!
    @IBOutlet weak var totalLabel: UILabel!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var storeAddressLabel: UILabel!
    @IBOutlet weak var storeOpenHoursLabel: UILabel!
    
    @IBOutlet weak var closeButtonTopSpaceConstraint: NSLayoutConstraint!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: ReservationDetailsViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *), let safeAreaTop = UIView.safeAreaFrame?.origin.y {
            closeButtonTopSpaceConstraint.constant = safeAreaTop + 14
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 0
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationView.alpha = 1
        }
        super.viewWillDisappear(animated)
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += productNameLabel.reactive.text <~ viewModel.productName
        disposables += createdLabel.reactive.text <~ viewModel.created
        disposables += totalLabel.reactive.text <~ viewModel.total
        disposables += storeNameLabel.reactive.text <~ viewModel.storeName
        disposables += storeAddressLabel.reactive.text <~ viewModel.storeAddress
        disposables += storeOpenHoursLabel.reactive.text <~ viewModel.storeOpeningHours
        disposables += viewModel.storeLocation.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            guard let coordinate = $0?.coordinate else { return }
            let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            self.mapView.setRegion(region, animated: true)

            let storeAnnotation =  MKPointAnnotation()
            storeAnnotation.coordinate = coordinate
            self.mapView.addAnnotation(storeAnnotation)
        }
        disposables += viewModel.productImageUrl.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in self.productImageView.sd_setImage(with: URL(string: $0)) }
    }

    @IBAction func closeReservationDetails(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
}

extension ReservationDetailsViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let reuseIdentifier = "storeAnnotation"
        if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier) {
            return annotationView
        }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIdentifier)
        annotationView.image = #imageLiteral(resourceName: "map_pin_active")
        return annotationView
    }
}
