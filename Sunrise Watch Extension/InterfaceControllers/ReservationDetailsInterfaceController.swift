//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import WatchKit
import Foundation
import ReactiveSwift
import SDWebImage

class ReservationDetailsInterfaceController: WKInterfaceController {
    
    @IBOutlet var productImage: WKInterfaceImage!
    @IBOutlet var productPriceLabel: WKInterfaceLabel!
    @IBOutlet var productNameLabel: WKInterfaceLabel!
    @IBOutlet var storeNameLabel: WKInterfaceLabel!
    @IBOutlet var storeMap: WKInterfaceMap!
    @IBOutlet var distanceLabel: WKInterfaceLabel!
    @IBOutlet var streetAndNumberLabel: WKInterfaceLabel!
    @IBOutlet var zipAndCityLabel: WKInterfaceLabel!
    @IBOutlet var openInfoLabel: WKInterfaceLabel!
    
    private var interfaceModel: ReservationDetailsInterfaceModel? {
        didSet {
            bindInterfaceModel()
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        setTitle("Close")
        interfaceModel = context as? ReservationDetailsInterfaceModel
    }

    private func bindInterfaceModel() {
        guard let interfaceModel = interfaceModel else { return }

        productNameLabel.setText(interfaceModel.productName)
        storeNameLabel.setText(interfaceModel.storeName)
        productPriceLabel.setText(interfaceModel.productPrice)
        distanceLabel.setText(interfaceModel.storeDistance)
        streetAndNumberLabel.setText(interfaceModel.streetAndNumberInfo)
        zipAndCityLabel.setText(interfaceModel.zipAndCityInfo)
        openInfoLabel.setText(interfaceModel.openingTimes)
        if let url = URL(string: interfaceModel.productImageUrl) {
            SDWebImageManager.shared().loadImage(with: url, options: [], progress: nil, completed: { [weak self] image, _, _, _, _, _ in
                if let image = image {
                    self?.productImage.setImage(image)
                }
            })
        }
        if let center = interfaceModel.storeLocation?.coordinate {
            storeMap.setRegion(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)))
            storeMap.addAnnotation(center, with: .red)
        }
    }

    @IBAction func getDirections() {
        interfaceModel?.getDirectionObserver.send(value: ())
    }
}
