//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class ProductsSectionViewController: UIViewController {
    
    @IBOutlet weak var sectionTitle: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    var numberOfItems = 2
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension ProductsSectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return numberOfItems
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.row {
        case 0:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath)
        case 1:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell2", for: indexPath)
        case 2:
            return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell3", for: indexPath)
            
        default:
            return UICollectionViewCell()
        }
        
    }
}
