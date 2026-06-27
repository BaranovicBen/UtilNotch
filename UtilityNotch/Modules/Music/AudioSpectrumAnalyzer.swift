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

    /// Explicit lifecycle state machine. Changes only on real engine transitions — NEVER on
    /// hover, re-render, or per-audio-buffer signal level. UI reads this for fallback/badge.
    enum Lifecycle: Equatable {
        case idle                  // not running, clean
        case requestingPermission  // waiting on the TCC prompt
        case starting              // engine spinning up
        case running               // tap installed, engine running
        case stopping              // tearing down
        case denied                // microphone permission denied / restricted
        case unavailable           // no input device
        case failed                // engine.start() threw

        var isRunningOrBusy: Bool {
            self == .running || self == .starting || self == .requestingPermission || self == .stopping
        }
    }

    /// Number of vertical bars — four musical bands:
    /// 0 Bass · 1 Low-mid · 2 High-mid · 3 Treble. Each value is 0...1.
    static let bandCount = 4

    private(set) var levels: [CGFloat] = Array(repeating: 0, count: bandCount)

    /// Coarse lifecycle (rarely changes). Drives the UI fallback/demo decision.
    private(set) var lifecycle: Lifecycle = .idle

    /// True when real audio energy is currently driving the bars. Updated per buffer for UI
    /// affordances only — it deliberately does NOT live in `lifecycle`, so it can flip many times
    /// a second without ever touching the audio engine.
    private(set) var hasSignal: Bool = false

    /// Deterministic demo motion shown ONLY when explicitly enabled. Clearly a preview, not real data.
    var previewMode = false {
        didSet {
            guard previewMode != oldValue else { return }   // idempotent — no churn on repeat-sets
            previewMode ? startPreview() : stopPreview()
        }
    }

    /// Recreated fresh on every start (see `startEngineCore`). Reusing a just-stopped engine is the
    /// direct cause of the transient -10877 (kAudioUnitErr_CannotDoInCurrentContext) on restart.
    private var engine = AVAudioEngine()
    private let processor = SpectrumProcessor(bandCount: AudioSpectrumAnalyzer.bandCount)
    private var isTapInstalled = false
    private var previewTimer: Timer?
    private var previewPhase: Double = 0

    /// Debounce teardown so rapid disappear→appear (panel open/close animations) doesn't churn
    /// the audio graph — the classic source of -10877 (kAudioUnitErr_CannotDoInCurrentContext).
    private var pendingStop: DispatchWorkItem?
    private let stopDebounce: TimeInterval = 0.25
    private var configObserver: NSObjectProtocol?

    private func log(_ msg: String) {
        #if DEBUG
        print("🎚️ [Analyzer] \(msg)")
        #endif
    }

    // Smoothing — snappy attack so bars jump on transients, quicker decay so columns
    // visibly fall between beats (the classic analyzer "bounce"). Tuned for energetic motion.
    private let attack: CGFloat = 0.78
    private let decay: CGFloat = 0.32

    /// Silence gate — below this smoothed level a band snaps to zero so silence stays still
    /// instead of shimmering on the noise floor.
    private let noiseGate: CGFloat = 0.05

    // UI-update throttle (~60 fps cap) to keep SwiftUI churn and CPU reasonable.
    private var lastPublishAt: TimeInterval = 0
    private let minPublishInterval: TimeInterval = 1.0 / 60.0

    // MARK: - Lifecycle (all on the main actor — a single serialized context)

    /// Request permission if needed, then start capture. Idempotent and hover-safe:
    /// repeated calls while already starting/running are no-ops.
    func start() {
        // A queued teardown means we're mid-debounce; cancelling it keeps the engine alive
        // without any stop/start cycle.
        if pendingStop != nil {
            pendingStop?.cancel()
            pendingStop = nil
            log("start: cancelled pending stop — engine stays up")
            return
        }
        guard !previewMode else { log("start skipped — preview mode"); return }
        guard !lifecycle.isRunningOrBusy else {
            log("start skipped — already \(lifecycle)")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startEngineCore()
        case .notDetermined:
            lifecycle = .requestingPermission
            log("start: requesting microphone permission")
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    if granted {
                        self.lifecycle = .idle           // allow startEngineCore's guard to pass
                        self.startEngineCore()
                    } else {
                        self.lifecycle = .denied
                        self.log("permission denied")
                    }
                }
            }
        case .denied, .restricted:
            lifecycle = .denied
            log("start: permission \(lifecycle)")
        @unknown default:
            lifecycle = .unavailable
        }
    }

    /// Stop capture. Debounced by default so quick disappear→appear doesn't tear down the graph.
    func stop(debounced: Bool = true) {
        guard debounced else { stopNow(); return }
        pendingStop?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingStop = nil
            self?.stopNow()
        }
        pendingStop = work
        log("stop: scheduled (debounced \(stopDebounce)s)")
        DispatchQueue.main.asyncAfter(deadline: .now() + stopDebounce, execute: work)
    }

    private func stopNow() {
        stopPreview()
        guard lifecycle == .running || lifecycle == .starting else {
            log("stopNow skipped — not running (\(lifecycle))")
            return
        }
        lifecycle = .stopping
        teardownEngine()
        lifecycle = .idle
        hasSignal = false
        decayToBaseline()
        log("stopNow: engine stopped, tap removed")
    }

    // MARK: - Engine core (guarded, never called from hover)

    private func startEngineCore() {
        guard lifecycle != .running, lifecycle != .starting else {
            log("startEngineCore skipped — \(lifecycle)")
            return
        }
        guard !isTapInstalled else { log("startEngineCore skipped — tap already installed"); return }
        lifecycle = .starting

        // Always start from a clean engine instance — a previously-stopped AVAudioEngine throws
        // -10877 when restarted. A fresh one has no stale render context.
        removeConfigObserver()
        engine = AVAudioEngine()

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        // A zero-channel / zero-rate format means there is no usable input device.
        guard format.channelCount > 0, format.sampleRate > 0 else {
            lifecycle = .unavailable
            log("startEngineCore: no usable input device")
            return
        }

        processor.configure(sampleRate: format.sampleRate)

        // [weak self] — no retain cycle; the tap closure never strongly holds the analyzer.
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            guard let bands = self.processor.process(buffer) else { return }
            Task { @MainActor in self.publish(bands) }
        }
        isTapInstalled = true
        log("tap installed @ \(Int(format.sampleRate))Hz")

        do {
            engine.prepare()
            try engine.start()
            lifecycle = .running
            installConfigObserver()
            log("engine started — running")
        } catch {
            let code = (error as NSError).code
            log("engine.start() FAILED code=\(code) ctx=\(error.localizedDescription)")
            teardownEngine()
            lifecycle = .failed
        }
    }

    /// Idempotent teardown — only removes a tap that exists and stops an engine that's running.
    private func teardownEngine() {
        removeConfigObserver()
        if isTapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
            log("tap removed")
        }
        if engine.isRunning {
            engine.stop()
            log("engine.stop()")
        }
    }

    // MARK: - Route / configuration changes

    private func installConfigObserver() {
        guard configObserver == nil else { return }
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleConfigChange() }
        }
    }

    private func removeConfigObserver() {
        if let o = configObserver {
            NotificationCenter.default.removeObserver(o)
            configObserver = nil
        }
    }

    /// Hardware/route changed (device added/removed, format change). Rebuild the graph through the
    /// same serialized guards rather than touching the engine from the notification context blindly.
    private func handleConfigChange() {
        guard lifecycle == .running else { return }
        log("config change — safely restarting graph")
        teardownEngine()
        lifecycle = .idle
        startEngineCore()
    }

    // MARK: - Publish / smoothing

    private func publish(_ bands: [Float]) {
        guard !previewMode else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastPublishAt >= minPublishInterval else { return }
        lastPublishAt = now

        var peak: CGFloat = 0
        var smoothed = levels
        for i in 0..<min(bands.count, smoothed.count) {
            let target = CGFloat(max(0, min(1, bands[i])))
            let rate = target > smoothed[i] ? attack : decay
            var v = smoothed[i] + (target - smoothed[i]) * rate
            if v < noiseGate { v = 0 }   // clean floor — no chaotic shimmer in silence
            smoothed[i] = v
            peak = max(peak, v)
        }
        levels = smoothed
        // Signal-level only — NEVER feeds `lifecycle`, so it can flip freely without engine ops.
        let nowHasSignal = peak > 0.03
        if nowHasSignal != hasSignal { hasSignal = nowHasSignal }
    }

    private func decayToBaseline() {
        levels = Array(repeating: 0, count: Self.bandCount)
    }

    // MARK: - Preview (deterministic, clearly labelled in the UI)

    private func startPreview() {
        // Free the mic immediately for demo mode (no debounce), but leave `lifecycle` as-is
        // (e.g. .denied) so the UI badge stays correct.
        stop(debounced: false)
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

    /// Four musical band edges in Hz (5 edges → 4 bands).
    /// Bass · Low-mid · High-mid · Treble. The very-high "air" range (12–16 kHz) is intentionally
    /// excluded — it is too weak/sparse in typical music and makes a dedicated bar look dead.
    private let bandEdgesHz: [Double] = [40, 160, 500, 3_500, 12_000]

    /// Mild perceptual tilt applied before auto-gain — nudges highs up so they cross the floor a
    /// touch sooner. The heavy lifting is done by per-band auto-gain (below), not by this tilt.
    private let bandGain: [Float] = [1.0, 1.3, 1.8, 2.4]

    /// Per-band rolling envelope (recent peak) for auto-gain. Music energy between bass and treble
    /// differs by tens of dB, so a single fixed dB window either saturates the lows or starves the
    /// treble. Normalizing each band against its own decaying peak makes all four bars independently
    /// lively — bass can't dominate and treble lights up on its own transients (hats/cymbals).
    private var bandEnv: [Float] = []
    private let envDecay: Float = 0.985          // ~1.5s fall at ~43 buffers/s
    private let envFloor: Float = 1e-7           // keeps the divisor sane; below this we gate
    private let masterSilenceDB: Float = -46     // overall level under this ⇒ output zeros (stable silence)

    init(bandCount: Int) {
        self.bandCount = bandCount
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        window = [Float](repeating: 0, count: fftSize)
        realp = [Float](repeating: 0, count: fftSize / 2)
        imagp = [Float](repeating: 0, count: fftSize / 2)
        windowed = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        bandEnv = [Float](repeating: envFloor, count: bandCount)
    }

    deinit { vDSP_destroy_fftsetup(fftSetup) }

    /// Map the fixed musical band edges → FFT bin ranges. Called once per format change.
    func configure(sampleRate: Double) {
        let nyquist = sampleRate / 2
        let binHz = sampleRate / Double(fftSize)
        var ranges: [(Int, Int)] = []
        for b in 0..<bandCount {
            let lo = bandEdgesHz[b]
            let hi = min(bandEdgesHz[b + 1], nyquist)
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

                        // Per-band auto-gain. Each band's tilted power is normalized against its own
                        // decaying envelope, so every bar (incl. treble) uses its full 0…1 range
                        // independently — no single fixed window to saturate the lows or starve the
                        // highs. A master silence gate keeps quiet passages at zero.

                        // 1) Raw tilted average power per band + overall level for the silence gate.
                        var raw = [Float](repeating: 0, count: bandCount)
                        var rawSum: Float = 0
                        for (b, range) in bandRanges.enumerated() {
                            var sum: Float = 0
                            for bin in range.0..<range.1 { sum += mags[bin] }
                            let avg = sum / Float(max(1, range.1 - range.0))
                            let gain = b < bandGain.count ? bandGain[b] : 1
                            raw[b] = avg * gain
                            rawSum += avg
                        }

                        // 2) Master gate — below this overall level, report silence (bands stay zero).
                        let masterDB = 10 * log10f(rawSum / Float(bandCount) + 1e-12) - 60
                        if masterDB < masterSilenceDB {
                            // Let envelopes decay so the meter wakes up smoothly when audio resumes.
                            for b in 0..<bandCount { bandEnv[b] = max(envFloor, bandEnv[b] * envDecay) }
                        } else {
                            // 3) Normalize each band against its own rolling peak.
                            for b in 0..<bandCount {
                                let v = raw[b]
                                bandEnv[b] = max(v, bandEnv[b] * envDecay)
                                let denom = max(bandEnv[b], envFloor)
                                var norm = v / denom
                                norm = max(0, min(1, norm))
                                norm = powf(norm, 0.60)    // gamma lift for visible low-level detail
                                bands[b] = norm
                            }
                        }
                    }
                }
            }
        }
        return bands
    }
}
