//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import UIKit
import ReactiveCocoa
import ReactiveSwift
import Result

class VoiceSearchViewController: UIViewController {

    private let disposables = CompositeDisposable()
    private var displayLink: CADisplayLink?
    
    @IBOutlet weak var recognizedTextLabel: UILabel!
    @IBOutlet weak var voiceLevelView: VoiceLevelView!
    
    deinit {
        disposables.dispose()
    }

    var viewModel: VoiceSearchViewModel? {
        didSet {
            self.bindViewModel()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        viewModel = VoiceSearchViewModel()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        displayLink = CADisplayLink(target: self, selector: #selector(updateMeter))
        displayLink?.add(to: .current, forMode: .common)
    }

    override func viewDidDisappear(_ animated: Bool) {
        viewModel?.dismissObserver.send(value: ())
        displayLink?.invalidate()

        super.viewDidDisappear(animated)
    }
    
    @IBAction func backgroundTap(_ sender: Any) {
        viewModel?.dismissObserver.send(value: ())
    }

    @objc func updateMeter() {
        guard let amplitude = viewModel?.currentAudioMeterValue else { return }
        voiceLevelView.update(amplitude: CGFloat(amplitude))
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
                if let appSettingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(appSettingsURL)
                }
                self?.dismiss(animated: true)
            }))
            self?.present(alertController, animated: true, completion: nil)
        })
    }
}
