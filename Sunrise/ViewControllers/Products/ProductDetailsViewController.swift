//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class ProductDetailsViewController: UIViewController {

    @IBOutlet weak var sizesCollectionView: UICollectionView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var similarItemsCollectionView: UICollectionView!
    @IBOutlet weak var imagesCollectionView: UICollectionView!
    @IBOutlet weak var imagesCollectionViewFlowLayout: UICollectionViewFlowLayout!

    @IBOutlet weak var imagesPageControl: UIPageControl!

    @IBOutlet weak var productDescriptionButton: UIButton!
    @IBOutlet weak var reserveInStoreButton: UIButton!
    @IBOutlet weak var addToBagButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var wishlistButton: UIButton!
    
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var productNameLabel: UILabel!

    @IBOutlet weak var productDescriptionHeight: NSLayoutConstraint!
    @IBOutlet weak var scrollableHeightConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollableHeightConstraint.constant -= productDescriptionHeight.constant
        productDescriptionHeight.constant = 0
        NotificationCenter.default.addObserver(forName: Foundation.Notification.Name.Navigation.backButtonTapped, object: nil, queue: .main) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }
        imagesCollectionViewFlowLayout.itemSize = CGSize(width: view.bounds.size.width, height: 500)
        colorsCollectionView.reloadSections([0])
        scrollViewDidScroll(colorsCollectionView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationBarLightMode = true
            SunriseTabBarController.currentlyActive?.backButton.alpha = 1
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        UIView.animate(withDuration: 0.3) {
            SunriseTabBarController.currentlyActive?.navigationBarLightMode = false
            SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        }
        super.viewWillDisappear(animated)
    }
}

extension ProductDetailsViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == sizesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath) as! SizeCell
            cell.selectedSizeImageView.isHidden = indexPath.row != 0
            return cell

        } else if collectionView == colorsCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCell", for: indexPath) as! ColorCell
            cell.selectedColorImageView.isHidden = indexPath.item != 0
            return cell

        } else if collectionView == imagesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductImageCell", for: indexPath) as! ProductImageCell
            return cell

        } else {
            switch indexPath.row {
            case 0:
                return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath)
            case 1:
                return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell2", for: indexPath)
            default:
                return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell3", for: indexPath)
            }
        }
    }
}

extension ProductDetailsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == colorsCollectionView else { return }
        let centerX = scrollView.contentOffset.x + 20
        for cell in (scrollView as! UICollectionView).visibleCells as! [ColorCell] {

            var offsetX = centerX - cell.center.x
            if offsetX < 0 {
                offsetX *= -1
            }

            cell.transform = CGAffineTransform(scaleX: 1, y: 1)
            if offsetX > 10 {
                var scaleX = 1 - (offsetX - 10) / scrollView.bounds.width
                scaleX = scaleX < 0.773 ? 0.773 : scaleX

                cell.colorView.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                cell.colorView.center = CGPoint(x: cell.contentView.bounds.width / 2 + (1 - scaleX) * cell.contentView.bounds.width / 2, y: cell.contentView.bounds.height / 2)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == colorsCollectionView || scrollView == sizesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: CGPoint(x: 0, y: 0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView == colorsCollectionView || scrollView == sizesCollectionView else { return }
        scrollToPage(scrollView, withVelocity: velocity)
    }

    func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        let cellWidth = scrollView == colorsCollectionView ? CGFloat(44) : CGFloat(61)
        let cellPadding = scrollView == colorsCollectionView ? CGFloat(5) : CGFloat(10)

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
