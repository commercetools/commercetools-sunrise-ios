//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import CoreLocation
import UserNotifications

class SettingsViewController: UIViewController {
    
    @IBOutlet weak var changePasswordButton: UIButton!
    @IBOutlet weak var notificationsSwitch: UISwitch!
    @IBOutlet weak var locationSwitch: UISwitch!

    private let locationManager = CLLocationManager()
    private let disposables = CompositeDisposable()
    
    deinit {
        disposables.dispose()
    }
    
    var viewModel: SettingsViewModel? {
        didSet {
            self.bindViewModel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        [notificationsSwitch, locationSwitch].forEach { $0.onTintColor = UIColor(patternImage: #imageLiteral(resourceName: "switch_background")) }

        locationManager.delegate = self
        viewModel = SettingsViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel?.refreshObserver.send(value: ())
        SunriseTabBarController.currentlyActive?.backButton.alpha = 1
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        SunriseTabBarController.currentlyActive?.backButton.alpha = 0
        super.viewWillDisappear(animated)
    }
    
    private func bindViewModel() {
        guard let viewModel = viewModel, isViewLoaded else { return }

        disposables += locationSwitch.reactive.isOn <~ viewModel.isLocationEnabled
        disposables += notificationsSwitch.reactive.isOn <~ viewModel.areNotificationsEnabled

        disposables += NotificationCenter.default.reactive
        .notifications(forName: Foundation.Notification.Name.Navigation.backButtonTapped)
        .observe(on: UIScheduler())
        .observeValues { [unowned self] _ in
            guard self.view.window != nil else { return }
            self.navigationController?.popViewController(animated: true)
        }

        disposables += viewModel.passwordChangedSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in
            self.presentPasswordChangeSuccessAlert()
        }

        disposables += viewModel.alertMessageSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] alertMessage in
            let alertController = UIAlertController(
                    title: viewModel.oopsTitle,
                    message: alertMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: self?.viewModel?.okAction, style: .cancel))
            self?.present(alertController, animated: true)
        })
    }

    // MARK: - IBActions
    
    @IBAction func changeNotifications(_ sender: UISwitch) {
        guard sender.isOn != viewModel?.areNotificationsEnabled.value else { return }

        switch (sender.isOn, viewModel?.notificationsAuthorizationStatus.value) {
        case (true, .some(.notDetermined)):
            UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { [unowned self] success, _ in
                self.viewModel?.areNotificationsEnabled.value = success
            }
        case (true, .some(.denied)):
            presentNotificationsEnableAlert()
        case (false, _):
            presentNotificationsDisableAlert()
        default:
            return
        }
    }
    
    @IBAction func changeLocation(_ sender: UISwitch) {
        guard sender.isOn != viewModel?.isLocationEnabled.value else { return }

        switch (sender.isOn, viewModel?.locationAuthorizationStatus.value) {
            case (true, .some(.notDetermined)):
                locationManager.requestWhenInUseAuthorization()
            case (true, .some(.denied)):
                presentLocationEnableAlert()
            case (false, _):
                presentLocationDisableAlert()
            default:
                return
        }
    }

    @IBAction func changePassword(_ sender: UIButton) {
        presentChangePasswordAlert()
    }

    // MARK: - Alert presentation

    private var settingsAction: UIAlertAction {
        return UIAlertAction(title: viewModel?.settingsAction, style: .default) { [unowned self] _ in
            self.viewModel?.refreshObserver.send(value: ())
            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
        }
    }

    private var okAction: UIAlertAction {
        return UIAlertAction(title: viewModel?.okAction, style: .default) { [unowned self] _ in
            self.viewModel?.refreshObserver.send(value: ())
        }
    }

    private func presentLocationEnableAlert() {
        let alertController = UIAlertController(title: viewModel?.locationServicesTitle, message: viewModel?.locationServicesEnabledMessage, preferredStyle: .alert)
        alertController.addAction(settingsAction)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    private func presentLocationDisableAlert() {
        let alertController = UIAlertController(title: viewModel?.locationServicesTitle, message: viewModel?.locationServicesDisabledMessage, preferredStyle: .alert)
        alertController.addAction(settingsAction)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    private func presentNotificationsEnableAlert() {
        let alertController = UIAlertController(title: viewModel?.notificationServicesTitle, message: viewModel?.notificationServicesEnabledMessage, preferredStyle: .alert)
        alertController.addAction(settingsAction)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    private func presentNotificationsDisableAlert() {
        let alertController = UIAlertController(title: viewModel?.notificationServicesTitle, message: viewModel?.notificationServicesDisabledMessage, preferredStyle: .alert)
        alertController.addAction(settingsAction)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    private func presentPasswordChangeSuccessAlert() {
        let alertController = UIAlertController(title: viewModel?.changePasswordTitle, message: viewModel?.changePasswordSuccessMessage, preferredStyle: .alert)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    private func presentChangePasswordAlert() {
        let alertController = UIAlertController(title: viewModel?.changePasswordTitle, message: viewModel?.changePasswordMessage, preferredStyle: .alert)
        alertController.addTextField { [unowned self] textField in
            textField.placeholder = NSLocalizedString("Current Password", comment: "Current Password")
            textField.isSecureTextEntry = true
            textField.returnKeyType = .next
            self.disposables += self.viewModel!.currentPassword <~ textField.reactive.continuousTextValues
        }
        alertController.addTextField { [unowned self] textField in
            textField.placeholder = NSLocalizedString("New Password", comment: "New Password")
            textField.isSecureTextEntry = true
            textField.returnKeyType = .next
            self.disposables += self.viewModel!.newPassword <~ textField.reactive.continuousTextValues
        }
        alertController.addTextField { [unowned self] textField in
            textField.placeholder = NSLocalizedString("Confirm Password", comment: "Confirm Password")
            textField.isSecureTextEntry = true
            self.disposables += self.viewModel!.confirmPassword <~ textField.reactive.continuousTextValues
        }
        let okAction = UIAlertAction(title: viewModel?.okAction, style: .default) { [unowned self] _ in
            self.viewModel?.changePasswordObserver.send(value: ())
        }
        let cancelAction = UIAlertAction(title: viewModel?.cancelAction, style: .cancel)
        alertController.addAction(okAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
}

extension SettingsViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        viewModel?.locationAuthorizationStatus.value = status
    }
}