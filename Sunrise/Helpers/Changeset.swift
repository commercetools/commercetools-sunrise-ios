//
// Copyright (c) 2016 Commercetools. All rights reserved.
//

import Foundation

struct Changeset {

    var deletions: [IndexPath]
    var modifications: [IndexPath]
    var insertions: [IndexPath]

    init(deletions: [IndexPath] = [], modifications: [IndexPath] = [], insertions: [IndexPath] = []) {
        self.deletions = deletions
        self.modifications = modifications
        self.insertions = insertions
    }
    
}
