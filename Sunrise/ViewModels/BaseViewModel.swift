//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result
import ObjectMapper
import Commercetools

class BaseViewModel {

    // Outputs
    let alertMessageSignal: Signal<String, NoError>

    let alertMessageObserver: Observer<String, NoError>

    // MARK: - Lifecycle

    init() {
        let (alertMessageSignal, alertMessageObserver) = Signal<String, NoError>.pipe()
        self.alertMessageSignal = alertMessageSignal
        self.alertMessageObserver = alertMessageObserver
    }

    func alertMessageForErrors(errors: [NSError]) -> String {
        return errors.map({
            var alertMessage = ""
            if let failureReason = $0.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
                alertMessage += "\(failureReason) :"
            }
            alertMessage += $0.localizedDescription
            return alertMessage
        }).joinWithSeparator("\n")
    }

}