//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift

extension UIViewController {

    func observeAlertMessageSignal(viewModel: BaseViewModel) -> Disposable? {
        return viewModel.alertMessageSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] alertMessage in
            let alertController = UIAlertController(
            title: viewModel.oopsTitle,
                    message: alertMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .cancel, handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }))
            self?.present(alertController, animated: true, completion: nil)
        })
    }
}