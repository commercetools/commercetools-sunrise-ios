//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation
import Commercetools

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

struct Project {
    private static let kProjectConfig = "ProjectConfig"
    private static let kSuiteName = "group.com.commercetools.Sunrise"
    
    static var config: Config? {
        #if PROD
            let configPath = "CommercetoolsProdConfig"
        #else
            let configPath = "CommercetoolsStagingConfig"
        #endif
        
        if let storedConfig = UserDefaults(suiteName: kSuiteName)?.dictionary(forKey: kProjectConfig), let configuration = Config(config: storedConfig as NSDictionary) {
            return configuration
        } else if let configuration = Config(path: configPath) {
            return configuration
        }
        return nil
    }
    
    static func update(config: NSDictionary) {
        UserDefaults(suiteName: kSuiteName)?.set(config, forKey: kProjectConfig)
        UserDefaults(suiteName: kSuiteName)?.synchronize()
    }
}
