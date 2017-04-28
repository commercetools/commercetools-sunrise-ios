//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

class VoiceSearchViewController: UIViewController {

    private let disposables = CompositeDisposable()
    
    @IBOutlet weak var recognizedTextLabel: UILabel!
    
    deinit {
        disposables.dispose()
    }

    var viewModel: VoiceSearchViewModel? {
        didSet {
            self.bindViewModel()
            viewModel?.requestAuthorizations()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = VoiceSearchViewModel()

        let gradient = CAGradientLayer()

        gradient.frame = view.bounds
        gradient.opacity = 0.8
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]

        view.layer.insertSublayer(gradient, at: 0)
        view.backgroundColor = UIColor.clear
    }
    
    @IBAction func backgroundTap(_ sender: Any) {
        viewModel?.dismissObserver.send(value: ())
    }

    // MARK: - Bindings

    private func bindViewModel() {
        guard let viewModel = viewModel else { return }

        recognizedTextLabel.reactive.text <~ viewModel.recognizedText

        disposables += viewModel.dismissSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] in
            self?.dismiss(animated: true)
        })

        disposables += viewModel.alertMessageSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] alertMessage in
            let alertController = UIAlertController(
                    title: viewModel.oopsTitle,
                    message: alertMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .default, handler: { [weak self] _ in self?.dismiss(animated: true)}))
            self?.present(alertController, animated: true, completion: nil)
        })

        disposables += viewModel.notAuthorizedSignal
        .observe(on: UIScheduler())
        .observeValues({ [weak self] in
            let alertController = UIAlertController(
                    title: viewModel.oopsTitle,
                    message: viewModel.notAuthorizedMessage,
                    preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: viewModel.okAction, style: .default, handler: { [weak self] _ in self?.dismiss(animated: true)}))
            alertController.addAction(UIAlertAction(title: viewModel.settingsAction, style: .cancel, handler: { [weak self] _ in
                if let appSettingsURL = URL(string: UIApplicationOpenSettingsURLString) {
                    UIApplication.shared.open(appSettingsURL)
                }
                self?.dismiss(animated: true)
            }))
            self?.present(alertController, animated: true, completion: nil)
        })
    }
}
