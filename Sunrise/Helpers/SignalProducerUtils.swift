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

extension UITableViewCell {
    func prepareForReuseSignalProducer() -> SignalProducer<Void, NoError> {
        return self.rac_prepareForReuseSignal.toSignalProducer()
        .map { _ in () }
        .flatMapError { _ in return SignalProducer<Void, NoError>.empty }
    }
}