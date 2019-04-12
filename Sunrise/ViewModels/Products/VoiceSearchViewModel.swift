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
    let startSpeechRecognitionObserver: Signal<Void, NoError>.Observer

    // Outputs
    let notAuthorizedSignal: Signal<Void, NoError>
    let startSpeechRecognitionSignal: Signal<Void, NoError>
    let dismissSignal: Signal<Void, NoError>
    let performSearchSignal: Signal<(String, Locale), NoError>
    let isRecognitionInProgress = MutableProperty(false)
    let recognizedText: MutableProperty<String>
    let notAuthorizedMessage = NSLocalizedString("Microphone and speech recognition have to be activated for this feature.", comment: "Speech permissions error")

    private var idleTimer: Timer?
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioRecorder: AVAudioRecorder?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    // Property set from within the speech recognition task, indicating whether a search will be performed, so we can
    // deactivate AVAudioSession or wait for the AVSpeechSynthesizer to complete the utterance.
    private var willPerformSearch = false
    private let notAuthorizedObserver: Signal<Void, NoError>.Observer
    private let performSearchObserver: Signal<(String, Locale), NoError>.Observer
    private let searchSuggestion = NSLocalizedString("Try: \"black sneakers\"", comment: "Speech black sneakers suggestion")
    private let disposables = CompositeDisposable()

    // MARK: Lifecycle

    override init() {
        (notAuthorizedSignal, notAuthorizedObserver) = Signal<Void, NoError>.pipe()
        (dismissSignal, dismissObserver) = Signal<Void, NoError>.pipe()
        (performSearchSignal, performSearchObserver) = Signal<(String, Locale), NoError>.pipe()
        (startSpeechRecognitionSignal, startSpeechRecognitionObserver) = Signal<Void, NoError>.pipe()
        recognizedText = MutableProperty(searchSuggestion)

        super.init()

        disposables += NotificationCenter.default.reactive
        .notifications(forName: UIApplication.willResignActiveNotification)
        .observeValues { [weak self] _ in
            self?.dismissObserver.send(value: ())
        }

        disposables += dismissSignal
        .filter { [unowned self] in !self.willPerformSearch }
        .observeValues { [weak self] in
            self?.stopSpeechRecognition()
        }
        
        disposables += startSpeechRecognitionSignal.observeValues { [weak self] in
            self?.requestAuthorizations()
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
        recognizedText.value = searchSuggestion
        willPerformSearch = false

        if isRecognitionInProgress.value {
            stopSpeechRecognition()
        }
        isRecognitionInProgress.value = true
        guard let recognizer = SFSpeechRecognizer() else {
            alertMessageObserver.send(value: "Cannot perform speech recognition with your locale")
            return
        }
        
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(AVAudioSession.Category.playAndRecord)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
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

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = recognizer.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] result, error in
            if let recognizedText = result?.bestTranscription.formattedString {
                self?.recognizedText.value = recognizedText
                self?.idleTimer?.invalidate()
                self?.idleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                    self?.recognitionRequest.endAudio()
                    self?.willPerformSearch = true
                    self?.performSearch()
                    self?.idleTimer?.invalidate()
                }
            }

            if self?.recognitionTask?.isCancelled == false && (result?.isFinal == true || error != nil) {
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
        isRecognitionInProgress.value = false
        guard recognitionTask?.isCancelled == false else { return }
        recognitionRequest.endAudio()
        inputNode?.removeTap(onBus: 0)
        recognitionTask?.cancel()
        audioEngine.stop()
        audioRecorder?.stop()
        if !willPerformSearch {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func performSearch() {
        guard recognitionTask?.isCancelled == false else { return }
        let recognizedText = self.recognizedText.value
        performSearchObserver.send(value: (recognizedText, Locale.current))

        let speechUtterance = String(format: NSLocalizedString("Showing items matching %@", comment: "Showing matching items message"), recognizedText)
        let speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer.delegate = AppDelegate.shared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speechSynthesizer.speak(AVSpeechUtterance(string: speechUtterance))
        }
    }
}
