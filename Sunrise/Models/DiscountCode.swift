//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Commercetools

extension DiscountCode {
    /// The textual representation used when presenting the discount code information to the customer.
    public var discountDetails: String {
        var discountDescription = code
        if let name = name?.localizedString {
            discountDescription += ": \(name)"
        }
        if let description = description?.localizedString {
            discountDescription = " (\(description)"
        }
        discountDescription += ":\n"
        cartDiscounts.forEach {
            if let name = $0.obj?.name.localizedString {
                discountDescription += name
            }
            if let description = $0.obj?.description?.localizedString {
                discountDescription = " (\(description)"
            }
            discountDescription += ": "
            if let permyriad = $0.obj?.value.permyriad {
                discountDescription += "\(permyriad / 100) %"
            } else if let money = $0.obj?.value.money {
                discountDescription += "\(money)"
            }
            discountDescription += "\n"
        }

        return discountDescription
    }
}