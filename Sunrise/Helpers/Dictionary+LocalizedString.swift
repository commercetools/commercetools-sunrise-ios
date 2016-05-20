//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation

extension Dictionary where Key: StringLiteralConvertible, Value: StringLiteralConvertible {

    var localizedString: Value? {
        let currentLocaleIdentifier = NSLocale.currentLocale().localeIdentifier

        if let key = currentLocaleIdentifier as? Key, localizedString = self[key] {
            return localizedString

        } else if let key = NSLocale.componentsFromLocaleIdentifier(currentLocaleIdentifier)["kCFLocaleLanguageCodeKey"] as? Key, localizedString = self[key] {
            return localizedString

        } else {
            return self.first?.1
        }
    }

}