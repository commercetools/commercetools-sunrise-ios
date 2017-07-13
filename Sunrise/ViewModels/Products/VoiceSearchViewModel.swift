//
// Copyright (c) 2017 Commercetools. All rights reserved.
//

import Speech
import AVFoundation
import ReactiveSwift
import Result

class VoiceSearchViewModel: BaseViewModel {

    // Inputs
    let dismissObserver: Signal<Void, NoError>.Observer

    // Outputs
    let notAuthorizedSignal: Signal<Void, NoError>
    let dismissSignal: Signal<Void, NoError>
    let recognizedText = MutableProperty(NSLocalizedString("Try: \"black sneakers\"", comment: "Speech black sneakers suggestion"))
    let notAuthorizedMessage = NSLocalizedString("Microphone and speech recognition have to be activated for this feature.", comment: "Speech permissions error")

    private var idleTimer: Timer?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioRecorder: AVAudioRecorder?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    // Property set from within the speech recognition task, indicating whether a search will be performed, so we can
    // deactivate AVAudioSession or wait for the AVSpeechSynthesizer to complete the utterance.
    private var willPerformSearch = false
    private let notAuthorizedObserver: Signal<Void, NoError>.Observer
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

        let recorderSettings: [String: AnyObject] = [AVSampleRateKey: 44100.0 as AnyObject,
                                                     AVFormatIDKey: NSNumber(value: kAudioFormatMPEG4AAC),
                                                     AVNumberOfChannelsKey: 1 as AnyObject,
                                                     AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue as AnyObject]

        audioRecorder = try? AVAudioRecorder(url: URL(fileURLWithPath:"/dev/null"), settings: recorderSettings)
        audioRecorder?.isMeteringEnabled = true
    }

    deinit {
        disposables.dispose()
    }

    func requestAuthorizations() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                AVAudioSession.sharedInstance().requestRecordPermission { response in
                    if response {
                        self.audioRecorder?.prepareToRecord()
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

    var currentAudioMeterValue: Float {
        guard let audioRecorder = audioRecorder else { return 0 }
        audioRecorder.updateMeters()
        return pow(10, audioRecorder.averagePower(forChannel: 0) / 20 + 1.2)
    }

    private func recognizeSpeech() {
        guard let recognizer = SFSpeechRecognizer() else {
            alertMessageObserver.send(value: "Cannot perform speech recognition with your locale")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true)
        } catch {
            alertMessageObserver.send(value: "\(error)")
            return
        }


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
                    self?.willPerformSearch = true
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
            audioRecorder?.record()
        } catch {
            alertMessageObserver.send(value: "\(error)")
        }
    }
    
    private func stopSpeechRecognition() {
        recognitionTask?.cancel()
        inputNode?.removeTap(onBus: 0)
        recognitionRequest.endAudio()
        audioEngine.stop()
        audioRecorder?.stop()
        if !willPerformSearch {
            try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
        }
    }

    private func performSearch() {
        dismissObserver.send(value: ())
        let recognizedText = self.recognizedText.value
        AppRouting.switchToSearch(query: recognizedText)

        let speechUtterance = String(format: NSLocalizedString("Showing items matching %@", comment: "Showing matching items message"), recognizedText)
        let speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = AppDelegate.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speechSynthesizer.speak(AVSpeechUtterance(string: speechUtterance))
        }
    }
}