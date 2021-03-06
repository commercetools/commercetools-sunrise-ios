//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift

class ProfileViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var profileAvatarImageView: UIImageView!
    @IBOutlet var headerView: UIView!
    @IBOutlet weak var signInContainerView: UIView!
    private weak var signInViewController: SignInViewController?
    
    @IBOutlet weak var helloCustomerLabel: UILabel!
    
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
    }

    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += helloCustomerLabel.reactive.text <~ viewModel.helloCustomer

        disposables += viewModel.isLoginHidden.producer
        .skipRepeats()
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] isLoginHidden in
            UIView.animate(withDuration: 0.3) {
                self.signInContainerView.alpha = isLoginHidden ? 0 : 1
            }
        }
        
        disposables += viewModel.profilePhoto.producer
        .observe(on: UIScheduler())
        .startWithValues { [unowned self] in
            self.profileAvatarImageView.image = $0 ?? #imageLiteral(resourceName: "default-profile-photo")
        }

        viewModel.signInViewModel = signInViewController?.viewModel
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let signInViewController = segue.destination as? SignInViewController {
            self.signInViewController = signInViewController
        } else if let myReservationsViewController = segue.destination as? MyReservationsViewController {
            _ = myReservationsViewController.view
            myReservationsViewController.viewModel?.pendingReservationDetailsId.value = (sender as? AppRouting.ShowReservationDetailsRequest)?.reservationId
        } else if let myOrdersViewController = segue.destination as? MyOrdersViewController {
            _ = myOrdersViewController.view
            myOrdersViewController.viewModel?.pendingOrderDetailsRequest.value = (sender as? AppRouting.ShowOrderDetailsRequest)
        }
    }
    
    @IBAction func presentProfilePhotoActions(_ sender: UIButton) {
        let alertController = UIAlertController(title: nil, message: "Change profile photo", preferredStyle: .actionSheet)
        if profileAvatarImageView.image != #imageLiteral(resourceName: "default-profile-photo") {
            alertController.addAction(UIAlertAction(title: "Remove current photo", style: .destructive, handler: { _ in
                let confirmController = UIAlertController(title: "Delete profile photo", message: "Are you sure you want to delete your current profile photo?", preferredStyle: .alert)
                confirmController.addAction(UIAlertAction(title: "Yes", style: .default, handler: { _ in
                    self.viewModel?.deleteProfilePhotoObserver.send(value: ())
                }))
                confirmController.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
                self.present(confirmController, animated: true)
            }))
        }
        alertController.addAction(UIAlertAction(title: "Choose from library", style: .default, handler: { _ in
            self.performSegue(withIdentifier: "showProfilePhoto", sender: self)
        }))
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alertController, animated: true)
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
                performSegue(withIdentifier: "showMyStyle", sender: self)
            case 3:
                performSegue(withIdentifier: "showAddressBook", sender: self)
            case 4:
                performSegue(withIdentifier: "showPayments", sender: self)
            case 5:
                performSegue(withIdentifier: "showStoreFinder", sender: self)
            case 6:
                performSegue(withIdentifier: "showSettings", sender: self)
            default:
                viewModel?.logoutObserver.send(value: ())
        }
    }
}
