//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Commercetools

extension LineItem: Equatable {
    public static func ==(lhs: LineItem, rhs: LineItem) -> Bool {
        return lhs.id == rhs.id
    }
}

extension ShoppingList.LineItem: Equatable {
    public static func ==(lhs: ShoppingList.LineItem, rhs: ShoppingList.LineItem) -> Bool {
        return lhs.id == rhs.id
    }
}