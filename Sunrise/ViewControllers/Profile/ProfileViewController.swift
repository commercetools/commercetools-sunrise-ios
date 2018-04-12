//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift

class ProfileViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var headerView: UIView!
    @IBOutlet weak var signInContainerView: UIView!
    private weak var signInViewController: SignInViewController?
    private let disposables = CompositeDisposable()

    deinit {
        disposables.dispose()
    }

    var viewModel: ProfileViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableHeaderView = headerView
        tableView.tableFooterView = UIView()
        viewModel = ProfileViewModel()
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += viewModel.isLoginHidden.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] isLoginHidden in
            UIView.animate(withDuration: 0.3) {
                self.signInContainerView.alpha = isLoginHidden ? 0 : 1
            }
        }

        viewModel.signInViewModel = signInViewController?.viewModel
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let signInViewController = segue.destination as? SignInViewController {
            self.signInViewController = signInViewController
        }

    }
}

extension ProfileViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 8
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell") as! ProfileCell
        let image: UIImage
        switch indexPath.row {
            case 0:
                image = #imageLiteral(resourceName: "my_orders")
            case 1:
                image = #imageLiteral(resourceName: "my_reservations")
            case 2:
                image = #imageLiteral(resourceName: "my_style")
            case 3:
                image = #imageLiteral(resourceName: "address_book")
            case 4:
                image = #imageLiteral(resourceName: "my_payments")
            case 5:
                image = #imageLiteral(resourceName: "store_finder")
            case 6:
                image = #imageLiteral(resourceName: "settings")
            default:
                image = #imageLiteral(resourceName: "logout")
        }
        let title: String
        switch indexPath.row {
            case 0:
                title = NSLocalizedString("My Orders", comment: "My Orders")
            case 1:
                title = NSLocalizedString("Reservations", comment: "Reservations")
            case 2:
                title = NSLocalizedString("My Style", comment: "My Style")
            case 3:
                title = NSLocalizedString("Address Book", comment: "Address Book")
            case 4:
                title = NSLocalizedString("Payment Details", comment: "Payment Details")
            case 5:
                title = NSLocalizedString("Store Finder", comment: "Store Finder")
            case 6:
                title = NSLocalizedString("Settings", comment: "Settings")
            default:
                title = NSLocalizedString("Logout", comment: "Logout")
        }
        cell.profileItemImageView.image = image
        cell.profileItemTitleLabel.text = title
        return cell
    }
}

extension ProfileViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.row {
            case 0:
                performSegue(withIdentifier: "showMyOrders", sender: self)
            case 1:
                performSegue(withIdentifier: "showMyReservations", sender: self)
            case 2:
                print("my style")
            case 3:
                performSegue(withIdentifier: "showAddressBook", sender: self)
            case 4:
                print("my payments")
            case 5:
                performSegue(withIdentifier: "showStoreFinder", sender: self)
            case 6:
                print("settings")
            default:
                viewModel?.logoutObserver.send(value: ())
        }
    }
}