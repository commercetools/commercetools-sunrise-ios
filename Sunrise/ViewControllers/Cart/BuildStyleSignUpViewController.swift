//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class BuildStyleSignUpViewController: UIViewController {

    @IBOutlet weak var gradientView: UIView!
    
    @IBOutlet weak var dressSizeCollectionView: UICollectionView!
    @IBOutlet weak var topSizeCollectionView: UICollectionView!
    @IBOutlet weak var bottomSizeCollectionView: UICollectionView!
    @IBOutlet weak var shoeSizeCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor(red:0.20, green:0.58, blue:1.00, alpha:1.0).cgColor, UIColor(red:0.22, green:0.96, blue:1.00, alpha:1.0).cgColor]
        gradientLayer.locations = [0.054, 0.541]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }

    @IBAction func skipSignUp(_ sender: UIButton) {
        (((presentingViewController as? UINavigationController)?.viewControllers.last as? UITabBarController)?.viewControllers?[5] as? UINavigationController)?.popViewController(animated: false)
        dismiss(animated: true)
    }

}

extension BuildStyleSignUpViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SizeCell", for: indexPath) as! SizeCell
        cell.selectedSizeImageView.isHidden = indexPath.row != 0
        return cell
    }
}

extension BuildStyleSignUpViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollToPage(scrollView, withVelocity: CGPoint(x: 0, y: 0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        scrollToPage(scrollView, withVelocity: velocity)
    }

    func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        let cellWidth = CGFloat(61)
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