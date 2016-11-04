//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools
import SDWebImage
import UIKit
import UserNotifications
import UserNotificationsUI

class ReservationNotificationViewController: UIViewController, UNNotificationContentExtension {
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var productImageView: UIImageView!
    @IBOutlet weak var productNameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var quantityLabel: UILabel!
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var streetAndNumberLabel: UILabel!
    @IBOutlet weak var zipAndCityLabel: UILabel!
    @IBOutlet weak var openLine1Label: UILabel!
    @IBOutlet weak var openLine2Label: UILabel!
    private let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
    
    var viewModel: ReservationViewModel? {
        didSet {
            self.bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        commercetoolsSDKSetup()
        
        containerView.alpha = 0
    }
    
    func didReceive(_ notification: UNNotification) {
        if let orderId = notification.request.content.userInfo["reservation-id"] as? String {
            Order.byId(orderId, expansion: ["lineItems[0].distributionChannel"]) { [weak self] result in
                if let order = result.model, result.isSuccess {
                    DispatchQueue.main.async {
                        self?.viewModel = ReservationViewModel(order: order)
                        UIView.animate(withDuration: 0.4) {
                            self?.loadingIndicator.stopAnimating()
                            self?.containerView.alpha = 1
                        }
                    }
                }
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadingIndicator.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view.addSubview(loadingIndicator)
        loadingIndicator.startAnimating()
    }
    
    // MARK: - Bindings
    
    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }
        
        productImageView.sd_setImage(with: URL(string: viewModel.productImageUrl))
        productNameLabel.text = viewModel.productName
        sizeLabel.text = viewModel.size
        quantityLabel.text = viewModel.quantity
        priceLabel.text = viewModel.price
        storeNameLabel.text = viewModel.storeName
        streetAndNumberLabel.text = viewModel.streetAndNumberInfo
        zipAndCityLabel.text = viewModel.zipAndCityInfo
        openLine1Label.text = viewModel.openLine1Info
    }
    
    // MARK: - Commercetools SDK
    
    private func commercetoolsSDKSetup() {
        if let configuration = Config(path: "CommercetoolsProdConfig") {
            Commercetools.config = configuration
        }
    }

}
