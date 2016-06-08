//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa

extension UIViewController {

    func observeAlertMessageSignal(viewModel viewModel: BaseViewModel) {
        viewModel.alertMessageSignal
        .observeOn(UIScheduler())
        .observeNext({ [weak self] alertMessage in
            let alertController = UIAlertController(
            title: "Oops!",
                    message: alertMessage,
                    preferredStyle: .Alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            self?.presentViewController(alertController, animated: true, completion: nil)
        })
    }
}