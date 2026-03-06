import SwiftUI

/// Music Control view — mock now-playing UI with playback controls.
/// Replace with real MediaPlayer / MRMediaRemote integration in production.
struct MusicControlView: View {
    @State private var isPlaying: Bool = true
    @State private var currentTrack: MockTrack = .sampleTracks[0]
    @State private var trackIndex: Int = 0
    @State private var progress: Double = 0.35
    @State private var volume: Double = 0.7
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Label("Music Control", systemImage: "music.note")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            Spacer()
            
            // Album art placeholder + track info
            HStack(spacing: 16) {
                // Album art
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: currentTrack.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.6))
                    )
                    .frame(width: 80, height: 80)
                
                // Track info
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentTrack.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(currentTrack.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Text(currentTrack.album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: geo.size.width * progress, height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(formatTime(progress * currentTrack.duration))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(formatTime(currentTrack.duration))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            
            // Playback controls
            HStack(spacing: 32) {
                Button(action: previousTrack) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                
                Button(action: togglePlayPause) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                
                Button(action: nextTrack) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            
            // Volume
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $volume, in: 0...1)
                    .tint(.white.opacity(0.5))
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Beta note
            Text("Mock playback • Real system integration requires Media & Apple Music permission")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    // MARK: - Actions (mock)
    
    private func togglePlayPause() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isPlaying.toggle()
        }
    }
    
    private func nextTrack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            trackIndex = (trackIndex + 1) % MockTrack.sampleTracks.count
            currentTrack = MockTrack.sampleTracks[trackIndex]
            progress = 0
        }
    }
    
    private func previousTrack() {
        withAnimation(.easeInOut(duration: 0.2)) {
            trackIndex = (trackIndex - 1 + MockTrack.sampleTracks.count) % MockTrack.sampleTracks.count
            currentTrack = MockTrack.sampleTracks[trackIndex]
            progress = 0
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Mock Track Model

private struct MockTrack {
    let title: String
    let artist: String
    let album: String
    let duration: Double // seconds
    let gradientColors: [Color]
    
    static let sampleTracks: [MockTrack] = [
        MockTrack(title: "Midnight City", artist: "M83", album: "Hurry Up, We're Dreaming", duration: 243,
                  gradientColors: [.indigo, .purple]),
        MockTrack(title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", duration: 200,
                  gradientColors: [.red, .orange]),
        MockTrack(title: "Starboy", artist: "The Weeknd", album: "Starboy", duration: 230,
                  gradientColors: [.blue, .cyan]),
        MockTrack(title: "Bohemian Rhapsody", artist: "Queen", album: "A Night at the Opera", duration: 354,
                  gradientColors: [.yellow, .orange]),
    ]
}
