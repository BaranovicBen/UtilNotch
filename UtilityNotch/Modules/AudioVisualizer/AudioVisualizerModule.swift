import SwiftUI

/// Audio Visualizer utility module — live vertical spectrum bars driven by microphone input.
/// See `AudioSpectrumAnalyzer` for the audio source rationale (sandbox + native API choice).
struct AudioVisualizerModule: UtilityModule {
    let id = "audioVisualizer"
    let name = "Audio Visualizer"
    let icon = "waveform"
    let contentTint = UNConstants.audioVisualizerContentTint
    var isEnabled = true

    var requiredPermissions: [PermissionInfo] {
        [
            PermissionInfo(
                id: "microphone",
                name: "Microphone",
                reason: "Captures live audio to drive the spectrum bars. Audio is analysed in real time and never recorded or stored.",
                systemSettingsPath: "Privacy & Security → Microphone"
            )
        ]
    }

    func makeMainView() -> AnyView {
        AnyView(AudioVisualizerModuleView())
    }

    func makeSettingsView() -> AnyView? {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio Visualizer Settings")
                    .font(.headline)
                Text("The visualizer reacts to live microphone input. Toggle preview motion from the module footer when no audio is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        )
    }
}
