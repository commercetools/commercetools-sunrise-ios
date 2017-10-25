//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class FiltersViewController: UIViewController {
    
    @IBOutlet weak var aToGBrandButton: UIButton!
    @IBOutlet weak var hToQBrandButton: UIButton!
    @IBOutlet weak var rToZBrandButton: UIButton!
    @IBOutlet weak var symbolBrandButton: UIButton!
    @IBOutlet weak var resetFiltersButton: UIButton!
    @IBOutlet weak var doneButton: UIButton!

    @IBOutlet weak var lowerPriceLabel: UILabel!
    @IBOutlet weak var higherPriceLabel: UILabel!
    
    @IBOutlet weak var priceSlider: RangeSlider!

    @IBOutlet weak var productTypesCollectionView: UICollectionView!
    @IBOutlet weak var brandsCollectionView: UICollectionView!
    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollViewDidScroll(productTypesCollectionView)
    }
}

extension FiltersViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == brandsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BrandCell", for: indexPath) as! BrandCell
            cell.selectedBrandImageView.isHidden = indexPath.item != 0
            return cell
            
        } else if collectionView == sizesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath) as! SizeCell
            cell.selectedSizeImageView.isHidden = indexPath.item != 1
            cell.sizeLabel.textColor = indexPath.item == 1 ? .white : UIColor(red:0.16, green:0.20, blue:0.25, alpha:1.0)
            return cell
            
        } else if collectionView == productTypesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductTypeCell", for: indexPath) as! ProductTypeCell
            cell.selectedProductImageView.isHidden = indexPath.item != 1
            return cell

        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
            cell.selectedColorImageView.isHidden = indexPath.item != 0
            return cell
        }
    }
}

extension FiltersViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == productTypesCollectionView else { return }

        let centerX = scrollView.contentOffset.x + 75
        for cell in (scrollView as! UICollectionView).visibleCells as! [ProductTypeCell] {

            var offsetX = centerX - cell.center.x
            if offsetX < 0 {
                offsetX *= -1
            }

            cell.transform = CGAffineTransform(scaleX: 1, y: 1)
            if offsetX > 30 {
                var scaleX = 1 - (offsetX - 30) / view.bounds.width
                scaleX = scaleX < 0.6 ? 0.6 : scaleX
                let productImageAlpha = 1.5 * scaleX - 0.5
                let productTitleAlpha = 3.33 * scaleX - 2.33

                cell.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                cell.productImageView.alpha = productImageAlpha
                cell.selectedProductImageView.alpha = productImageAlpha
                cell.productNameLabel.alpha = productTitleAlpha
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == productTypesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: CGPoint(x:0, y:0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView == productTypesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: velocity)
    }

    func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        let cellWidth = CGFloat(150)
        let cellPadding = CGFloat(10)

        var page: Int = Int((scrollView.contentOffset.x - cellWidth / 2) / (cellWidth + cellPadding) + 1)
        if velocity.x > 0 {
            page += 1
        }
        if velocity.x < 0 {
            page -= 1
        }
        page = max(page, 0)
        let newOffset: CGFloat = CGFloat(page) * (cellWidth + cellPadding)
        scrollView.setContentOffset(CGPoint(x: newOffset, y: 0), animated: true)
    }
}
