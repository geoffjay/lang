import AVFoundation
import Foundation

/// Captures one spoken utterance from the microphone as 16 kHz mono Float
/// samples (what WhisperKit wants), using energy-based voice-activity
/// detection to decide when you've stopped talking.
///
/// Unlike the old Apple-Speech path, Whisper has no built-in endpointing, so we
/// do our own: once we've heard speech, a stretch of trailing silence ends the
/// turn.
final class AudioCapture {
    enum CaptureError: LocalizedError {
        case engine(String)
        case format
        var errorDescription: String? {
            switch self {
            case .engine(let m): return "Audio engine error: \(m)"
            case .format: return "Could not set up audio conversion."
            }
        }
    }

    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false
    )!
    private var converter: AVAudioConverter?

    private let lock = NSLock()
    private var samples: [Float] = []
    private var continuation: CheckedContinuation<[Float], Error>?
    private var ending = false

    // VAD state (frame counts at 16 kHz).
    private var hasSpeech = false
    private var silentFrames = 0
    private var totalFrames = 0

    /// Listen until the speaker pauses; returns the utterance's samples
    /// (empty if no speech was detected).
    func captureUtterance() async throws -> [Float] {
        // Safe without the lock: the tap (the only other accessor) isn't
        // installed until below.
        samples = []; ending = false; hasSpeech = false; silentFrames = 0; totalFrames = 0

        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inFormat, to: targetFormat) else {
            throw CaptureError.format
        }
        self.converter = converter

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: inFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw CaptureError.engine(error.localizedDescription)
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
        }
    }

    /// Abort the current capture (user pressed Stop).
    func cancel() {
        finish(.success([]))
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1024)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var supplied = false
        var convErr: NSError?
        converter.convert(to: out, error: &convErr) { _, status in
            if supplied {
                status.pointee = .noDataNow
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if convErr != nil { return }

        let n = Int(out.frameLength)
        guard n > 0, let channel = out.floatChannelData?[0] else { return }

        var chunk = [Float](repeating: 0, count: n)
        var sumSquares: Float = 0
        for i in 0..<n {
            let v = channel[i]
            chunk[i] = v
            sumSquares += v * v
        }
        let rms = (sqrt(sumSquares / Float(n)))

        var snapshot: [Float]?
        lock.lock()
        if ending { lock.unlock(); return }
        samples.append(contentsOf: chunk)
        totalFrames += n
        if rms > Config.vadThreshold {
            hasSpeech = true
            silentFrames = 0
        } else if hasSpeech {
            silentFrames += n
        }

        let sr = Float(targetFormat.sampleRate)
        let silenceDur = Float(silentFrames) / sr
        let totalDur = Float(totalFrames) / sr
        let endBySilence = hasSpeech && silenceDur >= Float(Config.silenceTimeout)
        let endByMax = totalDur >= Float(Config.maxUtterance)
        let endByNoSpeech = !hasSpeech && totalDur >= Float(Config.noSpeechTimeout)

        if endBySilence || endByMax || endByNoSpeech {
            ending = true
            snapshot = endByNoSpeech ? [] : samples
        }
        lock.unlock()

        if let snapshot {
            // Tear down off the audio thread to avoid stopping the engine from
            // within its own render callback.
            DispatchQueue.main.async { [weak self] in
                self?.finish(.success(snapshot))
            }
        }
    }

    private func finish(_ result: Result<[Float], Error>) {
        lock.lock()
        ending = true
        let cont = continuation
        continuation = nil
        lock.unlock()

        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        cont?.resume(with: result)
    }
}
