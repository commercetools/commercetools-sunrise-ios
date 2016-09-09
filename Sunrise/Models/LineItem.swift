//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension LineItem: Equatable {}

public func ==(lhs: LineItem, rhs: LineItem) -> Bool {
    return lhs.id == rhs.id
}