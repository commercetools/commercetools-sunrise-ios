//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import MapKit
import SVProgressHUD
import SDWebImage

class StoreDetailsViewController: UIViewController {

    @IBOutlet weak var storeImageView: UIImageView!
    @IBOutlet weak var storeLocationMapView: MKMapView!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var streetAndNumberLabel: UILabel!
    @IBOutlet weak var zipAndCityLabel: UILabel!
    @IBOutlet weak var openLine1Label: UILabel!
    @IBOutlet weak var getDirectionsButton: UIButton!
    @IBOutlet weak var setAsMyStoreButton: UIButton!

    var viewModel: StoreDetailsViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        storeLocationMapView.isScrollEnabled = false
        storeLocationMapView.isZoomEnabled = false

        if viewModel != nil {
            bindViewModel()
        }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        storeImageView.sd_setImage(with: URL(string: viewModel.storeImageUrl))
        storeNameLabel.text = viewModel.storeName
        streetAndNumberLabel.text = viewModel.streetAndNumberInfo
        zipAndCityLabel.text = viewModel.zipAndCityInfo
        openLine1Label.text = viewModel.openLine1Info

        getDirectionsButton.reactive.pressed = CocoaAction(viewModel.getDirectionsAction)
        setAsMyStoreButton.reactive.pressed = CocoaAction(viewModel.saveMyStoreAction)

        viewModel.myStore?.producer
                .observe(on: UIScheduler())
                .startWithValues { [weak self] myStore in
                    self?.setAsMyStoreButton.isEnabled = myStore == nil || myStore!.id != viewModel.store.id
                    self?.setAsMyStoreButton.alpha = myStore == nil || myStore!.id != viewModel.store.id ? 1 : 0.7
                }

        viewModel.saveMyStoreAction.completed
                .observe(on: UIScheduler())
                .observeValues { [weak self] in
                    let alertController = UIAlertController(
                            title: viewModel.successTitle,
                            message: viewModel.successMessage,
                            preferredStyle: .alert
                    )
                    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                }

        if let storeLocation = viewModel.storeLocation {
            let mapViewRegion = MKCoordinateRegion(center: storeLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            storeLocationMapView.region = mapViewRegion

            let storeAnnotation =  MKPointAnnotation()
            storeAnnotation.coordinate = storeLocation.coordinate
            storeLocationMapView.addAnnotation(storeAnnotation)
        }
    }

}

extension StoreDetailsViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        if let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "storeAnnotation") {
            return annotationView
        }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "storeAnnotation")
        annotationView.image = UIImage(named: "map-pin")
        return annotationView
    }
}
