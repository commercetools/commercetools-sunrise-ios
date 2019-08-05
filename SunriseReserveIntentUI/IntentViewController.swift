import IntentsUI
import MapKit
import ReactiveSwift
import ReactiveCocoa
import SDWebImage

class IntentViewController: UIViewController, INUIHostedViewControlling {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productColorView: UIView!

    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var openHoursLabel: UILabel!
    @IBOutlet weak var storeAddressLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!

    private let locationManager = CLLocationManager()
    private var configureViewCompletion: ((Bool, Set<INParameter>, CGSize) -> Void)?
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: IntentViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        locationManager.delegate = self
        locationManager.distanceFilter = 50
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
        
        viewModel = IntentViewModel()
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel else { return }
        
        disposables += productNameLabel.reactive.text <~ viewModel.productName
        disposables += distanceLabel.reactive.text <~ viewModel.distance
        disposables += storeNameLabel.reactive.text <~ viewModel.storeName
        disposables += openHoursLabel.reactive.text <~ viewModel.openingTimes
        disposables += storeAddressLabel.reactive.text <~ viewModel.storeAddress
        disposables += sizeLabel.reactive.text <~ viewModel.size
        disposables += quantityLabel.reactive.text <~ viewModel.quantity
        
        disposables += viewModel.visibleMapRect.producer
        .observe(on: UIScheduler())
        .startWithValues { [weak self] visibleRegion in
            self?.mapView.setVisibleMapRect(visibleRegion, edgePadding: UIEdgeInsets(top: 60, left: 60, bottom: 60, right: 60), animated: true)
        }
        
        disposables += viewModel.channel.producer
        .filter { $0 != nil }
        .observe(on: UIScheduler())
        .startWithValues { [weak self] storeLocation in
            guard let mapView = self?.mapView, let coordinate = storeLocation?.location?.coordinate else { return }
            mapView.removeAnnotations(mapView.annotations)
            let storeAnnotation =  MKPointAnnotation()
            storeAnnotation.coordinate = coordinate
            mapView.addAnnotation(storeAnnotation)
        }
        
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
        
        disposables += viewModel.isLoading.producer
        .filter { !$0 }
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] _ in
            self.configureViewCompletion?(true, Set(), self.desiredSize)
        }
        
        disposables += viewModel.errorSignal
        .observe(on: UIScheduler())
        .observeValues { [weak self] in
            self?.configureViewCompletion?(false, Set(), .zero)
        }
    }
    
    // MARK: - INUIHostedViewControlling
    
    func configureView(for parameters: Set<INParameter>, of interaction: INInteraction, interactiveBehavior: INUIInteractiveBehavior, context: INUIHostedViewContext, completion: @escaping (Bool, Set<INParameter>, CGSize) -> Void) {
        guard let intent = interaction.intent as? ReserveProductIntent, let previousReservationId = intent.previousReservationId else {
            completion(false, Set(), .zero)
            return
        }
        viewModel?.previousReservationIdObserver.send(value: previousReservationId)
        configureViewCompletion = completion
    }
    
    var desiredSize: CGSize {
        return CGSize(width: extensionContext!.hostedViewMaximumAllowedSize.width, height: 501)
    }
}

extension IntentViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        viewModel?.userLocation.value = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint(error)
    }
}

extension IntentViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "activeStoreAnnotation")
        annotationView.image =  #imageLiteral(resourceName: "map_pin_active")
        return annotationView
    }
}
