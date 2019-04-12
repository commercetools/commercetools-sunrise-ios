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
        
        tableViewSafeZoneTopConstraint.constant = 53
    }
}

extension HomeViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.numberOfElements ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch viewModel?.element(at: indexPath) {
            case .some(.banner):
                let cell = tableView.dequeueReusableCell(withIdentifier: "BannerCell") as! BannerCell
                cell.bannerImageView.image = viewModel?.bannerImage(at: indexPath)
                return cell
            case .some(.inlinePOP):
                let cell = tableView.dequeueReusableCell(withIdentifier: "InlinePopCell")!
                let viewController = inlinePopViewControllers[indexPath, default: AppRouting.homeStoryboard.instantiateViewController(withIdentifier: "InlineProductOverviewViewController") as! InlineProductOverviewViewController]
                if viewController.viewModel == nil {
                    _ = viewController.view
                    viewController.viewModel = viewModel?.inlineProductOverviewViewModel(at: indexPath)
                    inlinePopViewControllers[indexPath] = viewController
                }
                addChild(viewController)
                viewController.didMove(toParent: self)
                viewController.view.frame = cell.contentView.bounds
                cell.contentView.addSubview(viewController.view)
                return cell
            case .some(.title):
                let cell = tableView.dequeueReusableCell(withIdentifier: "TitleCell") as! HomeTitleCell
                cell.sectionTitleLabel.text = viewModel?.title(at: indexPath)
                return cell
            default:
                return UITableViewCell()
        }
    }
}

extension HomeViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        viewModel?.selectedElementObserver.send(value: indexPath)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let viewModel = viewModel else { return 0 }
        switch viewModel.element(at: indexPath) {
            case .banner:
                return view.bounds.width / viewModel.aspectRatioForBanner(at: indexPath)
            case .inlinePOP:
                return 376
            case .title:
                return 66
        }
    }
}
