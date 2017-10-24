//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class FiltersViewController: UIViewController {
    
    @IBOutlet weak var aToGBrandButton: UIButton!
    @IBOutlet weak var hToQBrandButton: UIButton!
    @IBOutlet weak var rToZBrandButton: UIButton!
    @IBOutlet weak var symbolBrandButton: UIButton!
    
    @IBOutlet weak var lowerPriceLabel: UILabel!
    @IBOutlet weak var higherPriceLabel: UILabel!
    
    @IBOutlet weak var priceSlider: RangeSlider!
    
    @IBOutlet weak var brandsCollectionView: UICollectionView!
    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

extension FiltersViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == brandsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BrandCell", for: indexPath)
            return cell
            
        } else if collectionView == sizesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath)
            return cell
            
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath)
            return cell
        }
    }
}
