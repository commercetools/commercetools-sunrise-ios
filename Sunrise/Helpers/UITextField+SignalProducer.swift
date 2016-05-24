//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import ReactiveCocoa
import Result

extension UITextField {
    func signalProducer() -> SignalProducer<String, NoError> {
        return self.rac_textSignal().toSignalProducer()
        .map { $0 as! String }
        .flatMapError { _ in return SignalProducer<String, NoError>.empty }
    }
}