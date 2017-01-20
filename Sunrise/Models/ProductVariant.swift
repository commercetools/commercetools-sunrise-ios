//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension ProductVariant {

    /// The price without channel, customerGroup, country and validUntil/validFrom
    var independentPrice: Price? {
        return prices?.filter({ price in
            if price.channel == nil && price.customerGroup == nil && price.country == nil
               && price.validFrom == nil && price.validUntil == nil {
                return true
            }
            return false
        }).first
    }

    func price(for channel: Channel) -> Price? {
        guard let channelId = channel.id else { return nil }
        return prices?.filter({ $0.channel?.id == channelId }).first
    }
}