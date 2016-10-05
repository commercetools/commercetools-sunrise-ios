//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift

extension UIViewController {

    func observeAlertMessageSignal(viewModel: BaseViewModel) {
        viewModel.alertMessageSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] alertMessage in
            let alertController = UIAlertController(
            title: "Oops!",
                    message: alertMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            self?.present(alertController, animated: true, completion: nil)
        })
    }
}
