//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import MapKit
import ReactiveSwift
import ReactiveCocoa
import SVProgressHUD

class ReservationConfirmationViewController: UIViewController {
    
    @IBOutlet weak var getDirectionsButton: UIButton!
    
    @IBOutlet weak var storeNameLabel: UILabel!
    @IBOutlet weak var openHoursLabel: UILabel!
    @IBOutlet weak var storeAddressLabel: UILabel!

    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: ReservationConfirmationViewModel? {
        didSet {
            bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += storeNameLabel.reactive.text <~ viewModel.storeName
        disposables += openHoursLabel.reactive.text <~ viewModel.openingTimes
        disposables += storeAddressLabel.reactive.text <~ viewModel.storeAddress

        getDirectionsButton.reactive.pressed = CocoaAction(viewModel.getDirectionsAction)
    }
    
    @IBAction func continueShopping(_ sender: UIButton) {
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func showProfile(_ sender: UIButton) {
        AppRouting.showProfileTab()
        navigationController?.popToRootViewController(animated: false)
    }
}
