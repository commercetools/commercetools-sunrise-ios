//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation

extension Bundle {

    /**
     Locates the first bundle with a '.xctest' file extension.
     */
    internal static var currentTestBundle: Bundle? {
        return allBundles.lazy
            .filter {
                $0.bundlePath.hasSuffix(".xctest")
            }
            .first
    }

}

var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    return formatter
}()
var jsonDecoder: JSONDecoder = {
    let jsonDecoder = JSONDecoder()
    jsonDecoder.dateDecodingStrategy = .formatted(dateFormatter)
    jsonDecoder.dataDecodingStrategy = .deferredToData
    return jsonDecoder
}()
