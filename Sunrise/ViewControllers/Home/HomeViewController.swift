//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveSwift

class HomeViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewSafeZoneTopConstraint: NSLayoutConstraint!

    private var inlinePopViewControllers = [IndexPath: InlineProductOverviewViewController]()

    var viewModel: HomeViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
        viewModel = HomeViewModel()
        
        if #available(iOS 11, *) {
            tableViewSafeZoneTopConstraint.constant = 53
        } else {
            tableViewSafeZoneTopConstraint.constant = 33
        }
    }
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfElements ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if viewModel?.element(at: indexPath) == .banner {
            let cell = tableView.dequeueReusableCell(withIdentifier: "BannerCell") as! BannerCell
            cell.bannerImageView.image = viewModel?.bannerImage(at: indexPath)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "InlinePopCell")!
        let viewController = inlinePopViewControllers[indexPath, default: AppRouting.homeStoryboard.instantiateViewController(withIdentifier: "InlineProductOverviewViewController") as! InlineProductOverviewViewController]
        if viewController.viewModel == nil {
            _ = viewController.view
            viewController.viewModel = viewModel?.inlineProductOverviewViewModel(at: indexPath)
            inlinePopViewControllers[indexPath] = viewController
        }
        addChildViewController(viewController)
        viewController.didMove(toParentViewController: self)
        viewController.view.frame = cell.contentView.bounds
        cell.contentView.addSubview(viewController.view)
        return cell
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedElementObserver.send(value: indexPath)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = viewModel else { return 0 }
        if viewModel.element(at: indexPath) == .banner {
            return view.bounds.width / viewModel.aspectRatioForBanner(at: indexPath)
        }
        return 360
    }
}
