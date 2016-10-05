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
