//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation

struct Changeset {

    var deletions: [NSIndexPath]
    var modifications: [NSIndexPath]
    var insertions: [NSIndexPath]

    init(deletions: [NSIndexPath] = [], modifications: [NSIndexPath] = [], insertions: [NSIndexPath] = []) {
        self.deletions = deletions
        self.modifications = modifications
        self.insertions = insertions
    }
    
}
