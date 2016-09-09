//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension Customer {

    // Customer address used when making a reservation
    var reservationAddress: Address {
        var address = addresses?.filter({ $0.id ==  defaultBillingAddressId }).first ?? Address()
        address.firstName = firstName
        address.lastName = lastName
        return address
    }
}