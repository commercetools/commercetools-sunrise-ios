//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation

extension Dictionary where Key: ExpressibleByStringLiteral, Value: ExpressibleByStringLiteral {

    var localizedString: Value? {
        let currentLocaleIdentifier = Locale.current.identifier

        if let key = currentLocaleIdentifier as? Key, let localizedString = self[key] {
            return localizedString

        } else if let key = Locale.components(fromIdentifier: currentLocaleIdentifier)[NSLocale.Key.languageCode.rawValue] as? Key, let localizedString = self[key] {
            return localizedString

        } else {
            return self.first?.1
        }
    }

}
