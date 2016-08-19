//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import MapKit
import SVProgressHUD
import SDWebImage

class ReservationViewController: UIViewController {
    
    
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var storeLocationMapView: MKMapView!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var streetAndNumberLabel: UILabel!
    @IBOutlet weak var zipAndCityLabel: UILabel!
    @IBOutlet weak var openLine1Label: UILabel!
    @IBOutlet weak var openLine2Label: UILabel!

    var viewModel: ReservationViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        storeLocationMapView.scrollEnabled = false
        storeLocationMapView.zoomEnabled = false

        if viewModel != nil {
            bindViewModel()
        }
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel where isViewLoaded() else { return }

        viewModel.isLoading.producer
        .observeOn(UIScheduler())
        .startWithNext({ isLoading in
            if !isLoading {
                SVProgressHUD.dismiss()
            } else {
                SVProgressHUD.show()
            }
        })

        viewModel.storeLocation.producer
        .observeOn(UIScheduler())
        .startWithNext({ [weak self] storeLocation in
            if let storeLocation = storeLocation {
                let mapViewRegion = MKCoordinateRegion(center: storeLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                self?.storeLocationMapView.region = mapViewRegion

                let storeAnnotation =  MKPointAnnotation()
                storeAnnotation.coordinate = storeLocation.coordinate
                self?.storeLocationMapView.addAnnotation(storeAnnotation)
            }
        })

        productImageView.sd_setImageWithURL(NSURL(string: viewModel.productImageUrl))
        productNameLabel.text = viewModel.productName
        sizeLabel.text = viewModel.size
        quantityLabel.text = viewModel.quantity
        priceLabel.text = viewModel.price
        storeNameLabel.text = viewModel.storeName
        streetAndNumberLabel.text = viewModel.streetAndNumberInfo
        zipAndCityLabel.text = viewModel.zipAndCityInfo
        openLine1Label.text = viewModel.openLine1Info
        openLine2Label.text = viewModel.openLine2Info
    }

}
