//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Speech
import ReactiveSwift
import Result

class VoiceSearchViewModel: BaseViewModel {

    // Inputs
    let dismissObserver: Observer<Void, NoError>

    // Outputs
    let notAuthorizedSignal: Signal<Void, NoError>
    let dismissSignal: Signal<Void, NoError>
    let recognizedText = MutableProperty(NSLocalizedString("Try: \"summer dress\"", comment: "Speech summer dress suggestion"))
    let notAuthorizedMessage = NSLocalizedString("Microphone and speech recognition have to be activated for this feature.", comment: "Speech permissions error")

    private var idleTimer: Timer?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    private let notAuthorizedObserver: Observer<Void, NoError>
    private let disposables = CompositeDisposable()

    // MARK: Lifecycle

    override init() {
        (notAuthorizedSignal, notAuthorizedObserver) = Signal<Void, NoError>.pipe()

        (dismissSignal, dismissObserver) = Signal<Void, NoError>.pipe()

        super.init()

        disposables += NotificationCenter.default.reactive
        .notifications(forName: .UIApplicationWillResignActive)
        .observeValues { [weak self] _ in
            self?.dismissObserver.send(value: ())
        }

        disposables += dismissSignal.observeValues { [weak self] in
            self?.stopSpeechRecognition()
        }
    }

    deinit {
        disposables.dispose()
    }

    func requestAuthorizations() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                AVAudioSession.sharedInstance().requestRecordPermission { response in
                    if response {
                        self.recognizeSpeech()
                    } else {
                        self.notAuthorizedObserver.send(value: ())
                    }
                }
            } else {
                self.notAuthorizedObserver.send(value: ())
            }
        }
    }

    private func recognizeSpeech() {
        let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))!
        
        let audioSession = AVAudioSession.sharedInstance()

        try? audioSession.setCategory(AVAudioSessionCategoryRecord)
        try? audioSession.setMode(AVAudioSessionModeMeasurement)
        try? audioSession.setActive(true, with: .notifyOthersOnDeactivation)

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            alertMessageObserver.send(value: "Audio engine doesn't have an input node")
            return
        }

        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] result, error in
            if let recognizedText = result?.bestTranscription.formattedString {
                self?.recognizedText.value = recognizedText
                self?.idleTimer?.invalidate()
                self?.idleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    self?.recognitionRequest.endAudio()
                    self?.performSearch()
                }
            }

            if result?.isFinal == true || error != nil {
                self?.stopSpeechRecognition()
                if let error = error {
                    self?.alertMessageObserver.send(value: "\(error)")
                }
            }
        })

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            alertMessageObserver.send(value: "\(error)")
        }
    }
    
    private func stopSpeechRecognition() {
        recognitionTask?.cancel()
        inputNode?.removeTap(onBus: 0)
        recognitionRequest.endAudio()
        audioEngine.stop()
    }

    private func performSearch() {
        dismissObserver.send(value: ())
        let recognizedText = self.recognizedText.value
        OperationQueue.main.addOperation() {
            AppRouting.switchToSearch(query: recognizedText)
        }
    }
}
