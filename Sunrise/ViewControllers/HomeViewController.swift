//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit

class HomeViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewSafeZoneTopConstraint: NSLayoutConstraint!

    let newProductsViewController = UIStoryboard(name: "Home", bundle: nil).instantiateViewController(withIdentifier: "ProductsSectionViewController") as! ProductsSectionViewController
    let recommendedViewController = UIStoryboard(name: "Home", bundle: nil).instantiateViewController(withIdentifier: "RecommendedViewController") as! ProductsSectionViewController
    let onSaleViewController = UIStoryboard(name: "Home", bundle: nil).instantiateViewController(withIdentifier: "OnSaleViewController") as! ProductsSectionViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        newProductsViewController.numberOfItems = 3
        onSaleViewController.numberOfItems = 3
        
        if #available(iOS 11, *) {
            tableViewSafeZoneTopConstraint.constant = 53
        } else {
            tableViewSafeZoneTopConstraint.constant = 33
        }
    }
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 8
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            return tableView.dequeueReusableCell(withIdentifier: "banner1")!
        case 1:
            return tableView.dequeueReusableCell(withIdentifier: "banner2")!
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "newProducts")!
            addChildViewController(newProductsViewController)
            newProductsViewController.didMove(toParentViewController: self)
            newProductsViewController.view.frame = cell.contentView.bounds
            cell.contentView.addSubview(newProductsViewController.view)
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "recommended")!
            addChildViewController(recommendedViewController)
            recommendedViewController.didMove(toParentViewController: self)
            recommendedViewController.view.frame = cell.contentView.bounds
            cell.contentView.addSubview(recommendedViewController.view)
            return cell
        case 4:
            return tableView.dequeueReusableCell(withIdentifier: "banner3")!
        case 5:
            let cell = tableView.dequeueReusableCell(withIdentifier: "onSale")!
            addChildViewController(onSaleViewController)
            onSaleViewController.didMove(toParentViewController: self)
            onSaleViewController.view.frame = cell.contentView.bounds
            cell.contentView.addSubview(onSaleViewController.view)
            return cell
        case 6:
            return tableView.dequeueReusableCell(withIdentifier: "banner4")!
        case 7:
            return tableView.dequeueReusableCell(withIdentifier: "banner5")!
        default:
            return UITableViewCell()
        }
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 2 || indexPath.row == 3 || indexPath.row == 5 {
            return 360
        } else {
            return UITableViewAutomaticDimension
        }
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if cell.restorationIdentifier == "newProducts" {
            
            cell.contentView.addSubview(newProductsViewController.view)
        }
    }
}
