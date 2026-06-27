import AVFoundation
import Accelerate
import Foundation
import SwiftUI

/// Live audio spectrum source for the Audio Visualizer module.
///
/// ## Why microphone input
/// UtilityNotch is sandboxed (`com.apple.security.app-sandbox`). The only audio source
/// that yields real PCM samples — and therefore real frequency/amplitude data — without a
/// heavyweight permission is the microphone via `AVAudioEngine`'s input node.
///
/// System/app audio loopback would require ScreenCaptureKit + the Screen Recording TCC
/// permission (much heavier, user-hostile for a notch utility). The Music module's
/// MediaRemote bridge only exposes *metadata* (title, position) — never sample data — so it
/// cannot drive a real FFT. Microphone capture is the realistic native path here and reacts
/// to whatever is audible in the room, including audio playing through the speakers.
///
/// ## Pipeline
/// `inputNode` tap (render thread) → Hann window → real FFT (`vDSP`) → log-spaced bands →
/// hop to `@MainActor` → attack/decay smoothing → published `levels`.
///
/// ## Fallback
/// When permission is denied / restricted, no input device exists, or the engine can't start,
/// `state` reflects it and `levels` stay at the resting baseline (no fake motion). An optional,
/// clearly-labelled `previewMode` drives a deterministic sine sweep for demos — never random.
@MainActor
@Observable
final class AudioSpectrumAnalyzer {

    enum State: Equatable {
        case idle              // not running
        case denied            // microphone permission denied / restricted
        case unavailable       // no input device or engine failure
        case listening         // running, signal below the noise floor
        case active            // running, real signal driving the bars

        var isLive: Bool { self == .listening || self == .active }
    }

    /// Number of vertical bars. Each value is 0...1.
    static let bandCount = 16

    private(set) var levels: [CGFloat] = Array(repeating: 0, count: bandCount)
    private(set) var state: State = .idle

    /// Deterministic demo motion shown ONLY when explicitly enabled. Clearly a preview, not real data.
    var previewMode = false {
        didSet { previewMode ? startPreview() : stopPreview() }
    }

    private let engine = AVAudioEngine()
    private let processor = SpectrumProcessor(bandCount: AudioSpectrumAnalyzer.bandCount)
    private var isTapInstalled = false
    private var previewTimer: Timer?
    private var previewPhase: Double = 0

    // Smoothing — fast attack, slower decay reads as musical rather than jittery.
    private let attack: CGFloat = 0.55
    private let decay: CGFloat = 0.16

    // MARK: - Lifecycle

    /// Request permission if needed, then start capture. Safe to call repeatedly.
    func start() {
        guard !previewMode else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startEngine()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    granted ? self.startEngine() : (self.state = .denied)
                }
            }
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    func stop() {
        stopPreview()
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        if engine.isRunning { engine.stop() }
        if state.isLive { state = .idle }
        decayToBaseline()
    }

    // MARK: - Engine

    private func startEngine() {
        guard !isTapInstalled else { return }

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // A zero-channel / zero-rate format means there is no usable input device.
        guard format.channelCount > 0, format.sampleRate > 0 else {
            state = .unavailable
            return
        }

        processor.configure(sampleRate: format.sampleRate)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            // FFT runs on the audio render thread inside the Sendable processor.
            guard let bands = self.processor.process(buffer) else { return }
            Task { @MainActor in self.publish(bands) }
        }
        isTapInstalled = true

        do {
            engine.prepare()
            try engine.start()
            state = .listening
        } catch {
            input.removeTap(onBus: 0)
            isTapInstalled = false
            state = .unavailable
        }
    }

    // MARK: - Publish / smoothing

    private func publish(_ bands: [Float]) {
        guard !previewMode else { return }
        var peak: CGFloat = 0
        var smoothed = levels
        for i in 0..<min(bands.count, smoothed.count) {
            let target = CGFloat(max(0, min(1, bands[i])))
            let rate = target > smoothed[i] ? attack : decay
            smoothed[i] += (target - smoothed[i]) * rate
            peak = max(peak, smoothed[i])
        }
        levels = smoothed
        state = peak > 0.04 ? .active : .listening
    }

    private func decayToBaseline() {
        levels = Array(repeating: 0, count: Self.bandCount)
    }

    // MARK: - Preview (deterministic, clearly labelled in the UI)

    private func startPreview() {
        stop()
        state = .idle
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickPreview() }
        }
        RunLoop.main.add(timer, forMode: .common)
        previewTimer = timer
    }

    private func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        if !previewMode { decayToBaseline() }
    }

    private func tickPreview() {
        previewPhase += 0.18
        var next = levels
        for i in 0..<Self.bandCount {
            // Traveling sine across the bars — deterministic, not random.
            let wave = sin(previewPhase + Double(i) * 0.5)
            let env = 0.45 + 0.4 * sin(previewPhase * 0.5 + Double(i) * 0.2)
            next[i] = CGFloat(max(0.04, (wave * 0.5 + 0.5) * env))
        }
        levels = next
    }
}

// MARK: - Spectrum Processor (audio-thread DSP)

/// Performs the windowing + real FFT + log-band reduction off the main actor.
/// Owned by `AudioSpectrumAnalyzer` and only ever invoked from the single audio render
/// thread, so its mutable scratch buffers are not shared — hence `@unchecked Sendable`.
private final class SpectrumProcessor: @unchecked Sendable {

    private let bandCount: Int
    private let log2n: vDSP_Length = 10
    private let fftSize = 1024            // 2^10
    private var halfSize: Int { fftSize / 2 }

    private let fftSetup: FFTSetup
    private var window: [Float]
    private var realp: [Float]
    private var imagp: [Float]
    private var windowed: [Float]
    private var bandRanges: [(Int, Int)] = []

    init(bandCount: Int) {
        self.bandCount = bandCount
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = [Float](repeating: 0, count: fftSize)
        realp = [Float](repeating: 0, count: fftSize / 2)
        imagp = [Float](repeating: 0, count: fftSize / 2)
        windowed = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit { vDSP_destroy_fftsetup(fftSetup) }

    /// Build log-spaced band → bin ranges. Called once per format change.
    func configure(sampleRate: Double) {
        let minHz = 40.0
        let maxHz = min(16_000.0, sampleRate / 2)
        let binHz = sampleRate / Double(fftSize)
        var ranges: [(Int, Int)] = []
        for b in 0..<bandCount {
            let lo = minHz * pow(maxHz / minHz, Double(b) / Double(bandCount))
            let hi = minHz * pow(maxHz / minHz, Double(b + 1) / Double(bandCount))
            let loBin = max(1, Int(lo / binHz))
            let hiBin = max(loBin + 1, min(halfSize - 1, Int(hi / binHz)))
            ranges.append((loBin, hiBin))
        }
        bandRanges = ranges
    }

    /// Returns `bandCount` normalized magnitudes (0...1) or nil if the buffer is unusable.
    func process(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        let available = Int(buffer.frameLength)
        guard available > 0, !bandRanges.isEmpty else { return nil }

        // Window the latest fftSize frames (zero-pad if the buffer is short).
        let n = min(available, fftSize)
        vDSP_vmul(channel, 1, window, 1, &windowed, 1, vDSP_Length(n))
        if n < fftSize {
            for i in n..<fftSize { windowed[i] = 0 }
        }

        var bands = [Float](repeating: 0, count: bandCount)
        windowed.withUnsafeBufferPointer { wptr in
            wptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfSize) { cptr in
                realp.withUnsafeMutableBufferPointer { rp in
                    imagp.withUnsafeMutableBufferPointer { ip in
                        var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                        vDSP_ctoz(cptr, 2, &split, 1, vDSP_Length(halfSize))
                        vDSP_fft_zrip(fftSetup, &split, 1, log2n, FFTDirection(FFT_FORWARD))

                        var mags = [Float](repeating: 0, count: halfSize)
                        vDSP_zvmags(&split, 1, &mags, 1, vDSP_Length(halfSize))

                        // Reduce bins → log-spaced bands, scaled to a perceptual 0...1.
                        let floorDB: Float = -52
                        for (b, range) in bandRanges.enumerated() {
                            var sum: Float = 0
                            for bin in range.0..<range.1 { sum += mags[bin] }
                            let avg = sum / Float(max(1, range.1 - range.0))
                            let db = 10 * log10f(avg + 1e-9) - 60   // -60: tap reference offset
                            bands[b] = max(0, min(1, (db - floorDB) / -floorDB))
                        }
                    }
                }
            }
        }
        return bands
    }
}
