//
// Copyright (c) 2018 Commercetools. All rights reserved.
//

import CoreLocation
import UserNotifications
import Commercetools
import ReactiveSwift
import Result

class SettingsViewModel: BaseViewModel {
    
    // Inputs
    let refreshObserver: Signal<Void, NoError>.Observer
    let locationAuthorizationStatus = MutableProperty(CLAuthorizationStatus.notDetermined)
    let notificationsAuthorizationStatus = MutableProperty(UNAuthorizationStatus.notDetermined)
    let changePasswordObserver: Signal<Void, NoError>.Observer
    let currentPassword = MutableProperty<String?>("")
    let newPassword = MutableProperty<String?>("")
    let confirmPassword = MutableProperty<String?>("")

    // Outputs
    let isLocationEnabled = MutableProperty(false)
    let areNotificationsEnabled = MutableProperty(false)
    let passwordChangedSignal: Signal<Void, NoError>
    let isLoading = MutableProperty(true)

    // Dialogue texts
    let locationServicesTitle = NSLocalizedString("Location Services", comment: "Location Services")
    let locationServicesEnabledMessage = NSLocalizedString("Please enable location permission for Sunrise app", comment: "Location permission prompt")
    let locationServicesDisabledMessage = NSLocalizedString("Use settings to disable location permission for Sunrise app", comment: "Disable location instruction")

    let notificationServicesTitle = NSLocalizedString("Notifications", comment: "Notifications")
    let notificationServicesEnabledMessage = NSLocalizedString("Please enable notification permission for Sunrise app", comment: "Notification permission prompt")
    let notificationServicesDisabledMessage = NSLocalizedString("Use settings to disable notification permission for Sunrise app", comment: "Disable notification instruction")

    let changePasswordTitle = NSLocalizedString("Change Password", comment: "Change Password")
    let changePasswordMessage = NSLocalizedString("Please enter your current password, and the new one you would like to use:", comment: "Change Password Message")
    let changePasswordSuccessMessage = NSLocalizedString("Password successfully changed", comment: "Password Change Success")

    private let passwordChangedObserver: Signal<Void, NoError>.Observer
    private let locationManager = CLLocationManager()
    private let disposables = CompositeDisposable()
    
    // MARK: - Lifecycle
    
    override init() {
        let (refreshSignal, refreshObserver) = Signal<Void, NoError>.pipe()
        self.refreshObserver = refreshObserver

        let (changePasswordSignal, changePasswordObserver) = Signal<Void, NoError>.pipe()
        self.changePasswordObserver = changePasswordObserver

        (passwordChangedSignal, passwordChangedObserver) = Signal<Void, NoError>.pipe()

        super.init()

        disposables += NotificationCenter.default.reactive.notifications(forName: .UIApplicationDidBecomeActive)
        .observeValues { [unowned self] _ in self.refreshNotificationPermissionStatus() }

        disposables += isLocationEnabled <~ locationAuthorizationStatus.map { $0 == .authorizedAlways || $0 == .authorizedWhenInUse }
        disposables += areNotificationsEnabled <~ notificationsAuthorizationStatus.map { $0 == .authorized }
        disposables += isLocationEnabled <~ refreshSignal.map { [unowned self] in self.isLocationEnabled.value }

        disposables += refreshSignal
        .observe(on: UIScheduler())
        .observeValues { [unowned self] in self.refreshNotificationPermissionStatus() }

        disposables += changePasswordSignal
        .observe(on: QueueScheduler())
        .observeValues { [unowned self] in
            guard self.newPassword.value == self.confirmPassword.value else {
                self.alertMessageObserver.send(value: NSLocalizedString("New password and confirmation do not match", comment: "Passwords do not match"))
                return
            }
            self.changePassword()
        }
    }
    
    deinit {
        disposables.dispose()
    }

    private func refreshNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [unowned self] settings in
            self.notificationsAuthorizationStatus.value = settings.authorizationStatus
        }
    }

    // MARK: - Commercetools customer password change

    private func changePassword() {
        guard let currentPassword = currentPassword.value, let newPassword = newPassword.value else { return }
        isLoading.value = true
        Customer.profile { result in
            if let profile = result.model, result.isSuccess {
                Customer.changePassword(currentPassword: currentPassword, newPassword: newPassword, version: profile.version) { result in
                    if result.isSuccess {
                        self.isLoading.value = false
                        self.passwordChangedObserver.send(value: ())
                    } else if let errors = result.errors as? [CTError], result.isFailure {
                        self.isLoading.value = false
                        super.alertMessageObserver.send(value: self.alertMessage(for: errors))
                    }
                }
            } else if let errors = result.errors as? [CTError], result.isFailure {
                self.isLoading.value = false
                super.alertMessageObserver.send(value: self.alertMessage(for: errors))
            }
        }
    }
}