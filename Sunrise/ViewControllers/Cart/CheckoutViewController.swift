//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class CheckoutViewController: UIViewController {

    @IBOutlet weak var lineItemsTableView: UITableView!
    @IBOutlet weak var shippingMethodsTableView: UITableView!
    @IBOutlet weak var deliveryAddressCollectionView: UICollectionView!
    @IBOutlet weak var paymentCollectionView: UICollectionView!
    
    @IBOutlet weak var billingAsShippingSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lineItemsTableView.rowHeight = UITableViewAutomaticDimension
        shippingMethodsTableView.rowHeight = UITableViewAutomaticDimension

        deliveryAddressCollectionView.reloadSections([0])
        paymentCollectionView.reloadSections([0])
        scrollViewDidScroll(deliveryAddressCollectionView)
        scrollViewDidScroll(paymentCollectionView)
        
        billingAsShippingSwitch.onTintColor = UIColor(patternImage: #imageLiteral(resourceName: "switch_background"))
    }

    @IBAction func dismissCheckout(_ sender: UIButton) {
        (((presentingViewController as? UINavigationController)?.viewControllers.last as? UITabBarController)?.viewControllers?[5] as? UINavigationController)?.popViewController(animated: false)
        dismiss(animated: true)
    }
}

extension CheckoutViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionView == paymentCollectionView ? 3 : 2
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseIdentifier: String
        switch (collectionView, indexPath.item) {
            case (paymentCollectionView, 2), (deliveryAddressCollectionView, 1):
                reuseIdentifier = "AddNewCell"
            case (paymentCollectionView, _):
                reuseIdentifier = "PaymentCell"
            default:
                reuseIdentifier = "DeliveryAddressCell"
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        return cell
    }
}

extension CheckoutViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: tableView == lineItemsTableView ? "LineItemCell" : "ShippingMethodCell")!
    }
}

extension CheckoutViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = scrollView as? UICollectionView else { return }
        let centerX = scrollView.contentOffset.x + 130
        for cell in collectionView.visibleCells {

            var offsetX = centerX - cell.center.x
            if offsetX < 0 {
                offsetX *= -1
            }

            cell.transform = CGAffineTransform(scaleX: 1, y: 1)
            if offsetX > 30 {
                var scaleX = 1 - (offsetX - 30) / scrollView.bounds.width
                scaleX = scaleX < 0.598 ? 0.598 : scaleX


                cell.contentView.transform = CGAffineTransform(scaleX: scaleX, y: scaleX)
                cell.contentView.alpha = scaleX
                cell.contentView.center = CGPoint(x: cell.contentView.bounds.width / 2 - (1 - scaleX) * cell.contentView.bounds.width / 2, y: cell.contentView.bounds.height / 2)
            }
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView is UICollectionView else { return }
        scrollToPage(scrollView, withVelocity: CGPoint(x: 0, y: 0))
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView is UICollectionView else { return }
        scrollToPage(scrollView, withVelocity: velocity)
    }

    func scrollToPage(_ scrollView: UIScrollView, withVelocity velocity: CGPoint) {
        guard scrollView is UICollectionView else { return }
        let cellWidth = CGFloat(260)
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
