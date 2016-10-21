//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Order {
    var isReservation: Bool {
        return ((custom?["fields"] as? [String: Any])?["isReservation"] as? Bool) == true
    }
}