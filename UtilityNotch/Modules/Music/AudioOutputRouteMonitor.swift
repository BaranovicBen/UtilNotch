import CoreAudio
import Foundation
import Observation

// MARK: - Visualizer settings keys

enum MusicVizKey {
    static let source = "music.vizSource"   // MusicVizSource.rawValue — "dummy" or "live"
}

/// What drives the Music module's spectrum bars.
enum MusicVizSource: String, CaseIterable, Identifiable {
    case dummy   // deterministic-free organic random motion — never touches the mic
    case live    // real microphone FFT (auto-falls back to dummy on Bluetooth output)
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dummy: return "Animated"
        case .live:  return "Live mic"
        }
    }
}

// MARK: - Output route monitor

/// Watches the system's default audio **output** device and reports whether it's Bluetooth.
///
/// ## Why this exists
/// The live visualizer reads the microphone. When the user is on Bluetooth headphones (AirPods etc.)
/// the input mic is the *same* Bluetooth link — opening it forces the headset out of high-quality
/// playback (A2DP) into the two-way call profile (HFP/SCO), which audibly wrecks music quality.
/// So when a Bluetooth output is active we suppress the mic and fall back to the animated bars.
@MainActor
@Observable
final class AudioOutputRouteMonitor {

    private(set) var isBluetoothOutput: Bool = false

    @ObservationIgnored private var listening = false
    @ObservationIgnored private let listenerQueue = DispatchQueue(label: "com.utilitynotch.audioroute")
    @ObservationIgnored private var listenerBlock: AudioObjectPropertyListenerBlock?

    private var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    func start() {
        guard !listening else { return }
        listening = true
        refresh()

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // Listener fires on `listenerQueue`; hop to the main actor to mutate observable state.
            Task { @MainActor in self?.refresh() }
        }
        listenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            listenerQueue,
            block
        )
    }

    func stop() {
        guard listening, let block = listenerBlock else { return }
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultOutputAddress,
            listenerQueue,
            block
        )
        listenerBlock = nil
        listening = false
    }

    private func refresh() {
        isBluetoothOutput = Self.currentOutputIsBluetooth()
    }

    /// Reads the default output device's transport type. Read-only hardware info — no entitlement
    /// needed, works inside the app sandbox.
    private static func currentOutputIsBluetooth() -> Bool {
        var deviceID = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var outputAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let s = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &outputAddr, 0, nil, &size, &deviceID
        )
        guard s == noErr, deviceID != 0 else { return false }

        var transport = UInt32(0)
        var tSize = UInt32(MemoryLayout<UInt32>.size)
        var transportAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let ts = AudioObjectGetPropertyData(deviceID, &transportAddr, 0, nil, &tSize, &transport)
        guard ts == noErr else { return false }

        return transport == kAudioDeviceTransportTypeBluetooth
            || transport == kAudioDeviceTransportTypeBluetoothLE
    }
}
