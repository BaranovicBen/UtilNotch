import SwiftUI
import AppKit

/// Timer module — up to 24h, system sound alerts, notch-native compact visual when running.
struct TimerView: View {
    @Environment(AppState.self) private var appState

    // MARK: - State

    @State private var hours: Int = 0
    @State private var minutes: Int = 5
    @State private var seconds: Int = 0

    @State private var timerState: TimerRunState = .idle
    @State private var remainingSeconds: Int = 0
    @State private var totalSeconds: Int = 0
    @State private var runningTimer: Timer?
    @State private var selectedSound: TimerAlertSound = .glass
    @State private var showSoundPicker: Bool = false
    @State private var showCompletedBanner: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Timer", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                soundButton
            }
            .padding(.bottom, 14)

            if timerState == .idle {
                idleContent
            } else {
                runningContent
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear { /* keep timer running in background */ }
    }

    // MARK: - Idle Content

    @ViewBuilder
    private var idleContent: some View {
        VStack(spacing: 16) {
            // Time input — three spinners
            HStack(spacing: 0) {
                timeColumn(value: $hours, label: "HH", range: 0...23)
                separatorText(":")
                timeColumn(value: $minutes, label: "MM", range: 0...59)
                separatorText(":")
                timeColumn(value: $seconds, label: "SS", range: 0...59)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))

            // Quick presets
            HStack(spacing: 6) {
                ForEach(TimerPreset.allCases) { preset in
                    Button {
                        applyPreset(preset)
                    } label: {
                        Text(preset.label)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Start button
            Button(action: startTimer) {
                Text("Start Timer")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9)
                            .fill(totalInputSeconds > 0 ? Color.white.opacity(0.15) : Color.white.opacity(0.05))
                    )
                    .foregroundStyle(totalInputSeconds > 0 ? Color.white : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(totalInputSeconds == 0)
        }
    }

    // MARK: - Running Content

    @ViewBuilder
    private var runningContent: some View {
        VStack(spacing: 14) {
            // Progress ring + countdown
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 6)
                    .frame(width: 130, height: 130)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.blue.opacity(0.6), .purple.opacity(0.8)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Countdown text
                VStack(spacing: 1) {
                    Text(countdownText)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    if showCompletedBanner {
                        Text("Done!")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }

            // Controls
            HStack(spacing: 16) {
                Button(action: cancelTimer) {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                        Text("Cancel")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: togglePause) {
                    HStack(spacing: 5) {
                        Image(systemName: timerState == .running ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.semibold))
                        Text(timerState == .running ? "Pause" : "Resume")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Sound Picker Button

    @ViewBuilder
    private var soundButton: some View {
        Menu {
            ForEach(TimerAlertSound.allCases) { sound in
                Button {
                    selectedSound = sound
                    sound.preview()
                } label: {
                    HStack {
                        Text(sound.displayName)
                        if selectedSound == sound {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                Text(selectedSound.displayName)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Time Column Helper

    @ViewBuilder
    private func timeColumn(value: Binding<Int>, label: String, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 4) {
            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text(String(format: "%02d", value.wrappedValue))
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 52)

            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func separatorText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(.tertiary)
            .padding(.bottom, 18)
    }

    // MARK: - Computed

    private var totalInputSeconds: Int {
        hours * 3600 + minutes * 60 + seconds
    }

    private var progress: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(totalSeconds - remainingSeconds) / CGFloat(totalSeconds)
    }

    private var countdownText: String {
        let h = remainingSeconds / 3600
        let m = (remainingSeconds % 3600) / 60
        let s = remainingSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Timer Actions

    private func startTimer() {
        let total = totalInputSeconds
        guard total > 0 else { return }
        totalSeconds = total
        remainingSeconds = total
        timerState = .running
        showCompletedBanner = false
        scheduleTimer()
    }

    private func scheduleTimer() {
        runningTimer?.invalidate()
        runningTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                tick()
            }
        }
    }

    private func tick() {
        guard timerState == .running else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            timerFinished()
        }
    }

    private func timerFinished() {
        runningTimer?.invalidate()
        runningTimer = nil
        timerState = .idle
        selectedSound.play()
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) {
            showCompletedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showCompletedBanner = false }
        }
    }

    private func togglePause() {
        if timerState == .running {
            timerState = .paused
            runningTimer?.invalidate()
            runningTimer = nil
        } else if timerState == .paused {
            timerState = .running
            scheduleTimer()
        }
    }

    private func cancelTimer() {
        runningTimer?.invalidate()
        runningTimer = nil
        timerState = .idle
        remainingSeconds = 0
        showCompletedBanner = false
    }

    private func applyPreset(_ preset: TimerPreset) {
        hours = preset.hours
        minutes = preset.minutes
        seconds = 0
    }
}

// MARK: - Models

enum TimerRunState {
    case idle, running, paused
}

enum TimerPreset: String, CaseIterable, Identifiable {
    case oneMin   = "1m"
    case fiveMin  = "5m"
    case tenMin   = "10m"
    case thirtyMin = "30m"
    case oneHour  = "1h"

    var id: String { rawValue }
    var label: String { rawValue }

    var hours: Int {
        switch self {
        case .oneHour: return 1
        default: return 0
        }
    }

    var minutes: Int {
        switch self {
        case .oneMin:    return 1
        case .fiveMin:   return 5
        case .tenMin:    return 10
        case .thirtyMin: return 30
        case .oneHour:   return 0
        }
    }
}

enum TimerAlertSound: String, CaseIterable, Identifiable {
    case glass    = "Glass"
    case ping     = "Ping"
    case pop      = "Pop"
    case purr     = "Purr"
    case tink     = "Tink"
    case sosumi   = "Sosumi"
    case funk     = "Funk"
    case basso    = "Basso"
    case hero     = "Hero"
    case morse    = "Morse"

    var id: String { rawValue }
    var displayName: String { rawValue }

    func play() {
        NSSound(named: rawValue)?.play()
    }

    func preview() {
        NSSound(named: rawValue)?.play()
    }
}
