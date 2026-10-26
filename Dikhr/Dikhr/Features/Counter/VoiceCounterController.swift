import Foundation
import Speech
import AVFoundation

/// Listens to speech and increments the counter every time the dhikr phrase
/// is recognized (matches the original "Voice Counter": recite the thikr aloud
/// and the counter counts automatically).
@MainActor
final class VoiceCounterController: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    @Published var isListening = false
    @Published var liveTranscript: String = ""
    @Published var errorText: String?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var dhikrTokens: Set<String> = []
    private var countedTokens: Set<String> = []
    private var lastAutoCountAt = Date.distantPast
    var onDhikrDetected: (() -> Void)?

    func configure(dhikrName: String) {
        let locale = Locale(identifier: "ar-SA")
        let rec = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
        recognizer = rec
        recognizer?.delegate = self
        // Match on the most distinctive word of the dhikr (longest token)
        let normalized = dhikrName.replacingOccurrences(of: "ا", with: "ا")
        dhikrTokens = Set(
            normalized
                .split(separator: " ")
                .map { String($0) }
                .filter { $0.count > 1 }
        )
        countedTokens = []
        lastAutoCountAt = Date.distantPast
    }

    func start() {
        errorText = nil
        SFSpeechRecognizer.requestAuthorization { [weak self] _ in
            Task { @MainActor in
                guard let self, let recognizer = self.recognizer, recognizer.isAvailable else {
                    self?.errorText = DikhrStrings.tr("التعرف على الصوت غير متاح", "Speech recognition unavailable")
                    return
                }
                AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                    Task { @MainActor in
                        guard let self else { return }
                        guard granted, self.beginRecognition() else {
                            self.errorText = DikhrStrings.tr("ميكروفون غير متاح", "Microphone unavailable")
                            return
                        }
                        self.isListening = true
                    }
                }
            }
        }
    }

    private func beginRecognition() -> Bool {
        guard let recognizer else { return false }
        let request = SFSpeechAudioBufferRecognitionRequest()
        self.request = request
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    self?.handle(result: result, error: error)
                }
            }
            return true
        } catch {
            errorText = DikhrStrings.tr("تعذر بدء ميكروفون: \(error.localizedDescription)",
                                        "Could not start microphone: \(error.localizedDescription)")
            return false
        }
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            liveTranscript = text
            if let token = dhikrTokens.first(where: { text.contains($0) }) {
                let occurrences = text.components(separatedBy: token).count - 1
                if occurrences > countedOccurrences {
                    let delta = occurrences - countedOccurrences
                    countedOccurrences = occurrences
                    // Counter Delay (original "Counter Delay: %lld seconds"):
                    // throttle automatic increments to at most one per the
                    // configured delay window; extra detections within the
                    // window are dropped.
                    let delay = CounterDelayStore.seconds
                    for _ in 0..<delta {
                        if delay > 0 {
                            let now = Date()
                            guard now.timeIntervalSince(lastAutoCountAt) >= Double(delay) else { continue }
                            lastAutoCountAt = now
                        }
                        onDhikrDetected?()
                    }
                }
            }
        }
        if error != nil {
            stop()
        }
    }

    private var countedOccurrences = 0

    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isListening = false
    }

    func toggle(dhikrName: String) {
        if isListening {
            stop()
        } else {
            configure(dhikrName: dhikrName)
            start()
        }
    }
}