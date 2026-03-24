import SwiftUI
import AppKit

// ITERATION5_NOTE: Native iOS/macOS Clock app timer detection
// Attempted approaches:
//   1. EventKit — exposes Calendar/Reminder data only; no timer/stopwatch state.
//   2. NSUserActivity — Clock app does not publish userActivity of type "timer".
//   3. UserDefaults with app group — Clock app uses no shared container (sandboxed, private).
//   4. AppleScript — Clock app is not scriptable on macOS (no script dictionary).
//   5. Continuity/Handoff — timer state is not surfaced via any public Handoff API.
//   6. Accessibility — Clock app is not exposed as an accessibility element on macOS.
// Conclusion: There is no public macOS API to read the system Clock timer state.
// The best-effort fallback implemented here is the module's own in-app timer,
// which is persistent, reliable, and does not require any entitlements.
// The "System Timer" / "App Timer" label is shown but always reads "App Timer"
// until Apple exposes a public API.

/// Timer module — large mechanical-digit display, preset quickstart, notch-native running state.
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
    @State private var showCompletedBanner: Bool = false
    @State private var glowPulse: Bool = false        // ambient glow pulse when running

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ─────────────────────────────────────────────
            HStack {
                Label("Timer", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                // Timer source indicator — always "App Timer" (see ITERATION5_NOTE above)
                Text("App Timer")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 4)
                soundButton
            }
            .padding(.bottom, 12)

            if timerState == .idle {
                idleContent
            } else {
                runningContent
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onDisappear { /* keep timer running in background — timer var is @State, lives with view */ }
    }

    // MARK: - Idle Content

    @ViewBuilder
    private var idleContent: some View {
        VStack(spacing: 14) {
            // Large digit input — HH : MM : SS
            HStack(spacing: 0) {
                timeColumn(value: $hours,   label: "h",  range: 0...23)
                colonSeparator
                timeColumn(value: $minutes, label: "m",  range: 0...59)
                colonSeparator
                timeColumn(value: $seconds, label: "s",  range: 0...59)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 10)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Quick presets — compact pill row
            HStack(spacing: 6) {
                ForEach(TimerPreset.allCases) { preset in
                    Button { applyPreset(preset) } label: {
                        Text(preset.label)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.07), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Start button
            Button(action: startTimer) {
                Text("Start")
                    .font(.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(totalInputSeconds > 0
                                  ? Color.blue.opacity(0.25)
                                  : Color.white.opacity(0.05))
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
        VStack(spacing: 12) {
            // ── Large countdown display ─────────────────────────────
            ZStack {
                // Ambient glow ring (visible when running)
                if timerState == .running {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.blue.opacity(0.0), .blue.opacity(0.4), .purple.opacity(0.4), .blue.opacity(0.0)],
                                center: .center
                            ),
                            lineWidth: glowPulse ? 12 : 8
                        )
                        .frame(width: 148, height: 148)
                        .blur(radius: glowPulse ? 10 : 6)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                            value: glowPulse
                        )
                        .onAppear { glowPulse = true }
                        .onDisappear { glowPulse = false }
                }

                // Track ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 138, height: 138)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [.blue.opacity(0.7), .purple.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 138, height: 138)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Countdown digits — large SF Mono mechanical feel
                VStack(spacing: 0) {
                    Text(countdownText)
                        .font(.system(size: 36, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.spring(response: 0.25), value: remainingSeconds)

                    if showCompletedBanner {
                        Text("Done!")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                    } else {
                        Text(timerState == .paused ? "Paused" : "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // ── Controls — icon-only compact row ────────────────────
            HStack(spacing: 20) {
                // Cancel
                controlButton(icon: "xmark", label: "Cancel", dim: true) {
                    cancelTimer()
                }

                // Pause / Resume — larger
                Button(action: togglePause) {
                    Image(systemName: timerState == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .help(timerState == .running ? "Pause" : "Resume")

                // Reset (back to last set time)
                controlButton(icon: "arrow.counterclockwise", label: "Reset", dim: true) {
                    resetTimer()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    // MARK: - Sound Button

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

    // MARK: - Time Column

    @ViewBuilder
    private func timeColumn(value: Binding<Int>, label: String, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 3) {
            // Up
            Button {
                if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 16)
            }
            .buttonStyle(.plain)

            // Value — large mono digit
            Text(String(format: "%02d", value.wrappedValue))
                .font(.system(size: 32, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(width: 54)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.2), value: value.wrappedValue)

            // Down
            Button {
                if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 16)
            }
            .buttonStyle(.plain)

            // Unit label
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.tertiary)
                .tracking(1)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var colonSeparator: some View {
        Text(":")
            .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.25))
            .padding(.bottom, 14)
    }

    // MARK: - Control Button Helper

    @ViewBuilder
    private func controlButton(icon: String, label: String, dim: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(dim ? .secondary : .white)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(dim ? 0.06 : 0.10))
                )
        }
        .buttonStyle(.plain)
        .help(label)
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
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
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

    private func resetTimer() {
        runningTimer?.invalidate()
        runningTimer = nil
        remainingSeconds = totalSeconds
        timerState = .running
        scheduleTimer()
    }

    private func scheduleTimer() {
        runningTimer?.invalidate()
        runningTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in tick() }
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
        glowPulse = false
        selectedSound.play()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showCompletedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showCompletedBanner = false }
        }
    }

    private func togglePause() {
        if timerState == .running {
            timerState = .paused
            glowPulse = false
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
        glowPulse = false
        remainingSeconds = 0
        showCompletedBanner = false
    }

    private func applyPreset(_ preset: TimerPreset) {
        hours   = preset.hours
        minutes = preset.minutes
        seconds = 0
    }
}

// MARK: - Models

enum TimerRunState {
    case idle, running, paused
}

enum TimerPreset: String, CaseIterable, Identifiable {
    case oneMin    = "1m"
    case fiveMin   = "5m"
    case tenMin    = "10m"
    case thirtyMin = "30m"
    case oneHour   = "1h"

    var id: String { rawValue }
    var label: String { rawValue }

    var hours: Int {
        switch self { case .oneHour: return 1; default: return 0 }
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
    case glass = "Glass", ping = "Ping", pop = "Pop", purr = "Purr",
         tink = "Tink", sosumi = "Sosumi", funk = "Funk",
         basso = "Basso", hero = "Hero", morse = "Morse"

    var id: String { rawValue }
    var displayName: String { rawValue }
    func play()    { NSSound(named: rawValue)?.play() }
    func preview() { NSSound(named: rawValue)?.play() }
}
