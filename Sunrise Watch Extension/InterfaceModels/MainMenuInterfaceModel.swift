//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import Foundation
import ReactiveSwift
import Commercetools

class MainMenuInterfaceModel {

    // Inputs

    // Outputs
    let presentSignInMessage: MutableProperty<Bool>

    // MARK: - Lifecycle

    init() {
        presentSignInMessage = MutableProperty(Commercetools.authState != .customerToken)

        NotificationCenter.default.addObserver(self, selector: #selector(checkAuthState), name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Commercetools.Notification.Name.WatchSynchronization.DidReceiveTokens, object: nil)
    }

    @objc private func checkAuthState() {
        presentSignInMessage.value = Commercetools.authState != .customerToken
    }
}
