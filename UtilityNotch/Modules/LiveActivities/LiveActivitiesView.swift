import SwiftUI
import Combine

// MARK: - Main View

struct LiveActivitiesView: View {
    @Environment(AppState.self) private var appState
    @State private var showAdd = false
    @State private var now: Date = .init()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Live Activities", systemImage: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 10)

            if appState.liveActivities.isEmpty {
                emptyState
            } else {
                activitiesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(ticker) { now = $0 }
        .sheet(isPresented: $showAdd) {
            AddActivitySheet(isPresented: $showAdd)
                .environment(appState)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No active sessions")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Tap + to start tracking")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Activities List

    private var activitiesList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(appState.liveActivities) { activity in
                    ActivityCard(activity: activity, now: now, onStop: { stop(activity) })
                        // LIVEACTIVITY_NOTE: Spring entry animation implies "split from notch" continuity.
                        // True matchedGeometryEffect across NSWindow boundaries is unsupported on macOS —
                        // the AmbientPillController fades the pill out as the panel fades in, and cards
                        // spring-scale in from a smaller anchor to imply the pill expanded into this view.
                        .transition(.scale(scale: 0.88, anchor: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Actions

    private func stop(_ activity: LiveActivity) {
        withAnimation(.easeOut(duration: 0.2)) {
            appState.liveActivities.removeAll { $0.id == activity.id }
        }
    }
}

// MARK: - Activity Card

private struct ActivityCard: View {
    let activity: LiveActivity
    let now: Date
    let onStop: () -> Void

    @State private var isHovering = false

    private var elapsed: TimeInterval { now.timeIntervalSince(activity.startDate) }
    private var remaining: TimeInterval? {
        guard let end = activity.endDate else { return nil }
        return max(0, end.timeIntervalSince(now))
    }
    private var progress: Double? {
        guard let end = activity.endDate else { return nil }
        let total = end.timeIntervalSince(activity.startDate)
        guard total > 0 else { return 1 }
        return min(1, elapsed / total)
    }
    private var accentColor: Color { Color(activityHex: activity.colorHex) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Colored icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                    Image(systemName: activity.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(accentColor)
                }

                // Name + time
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(timeLabel)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Stop button
                Button(action: onStop) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(isHovering ? .white : Color.white.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)

            // Progress bar (only when endDate is set)
            if let p = progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor.opacity(0.65))
                            .frame(width: geo.size.width * p)
                            .animation(.linear(duration: 0.9), value: p)
                    }
                }
                .frame(height: 3)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.08 : 0.05))
        )
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
    }

    private var timeLabel: String {
        if let rem = remaining {
            return rem == 0 ? "Done" : "\(formatDuration(rem)) left"
        }
        return "\(formatDuration(elapsed)) elapsed"
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Add Activity Sheet

private struct AddActivitySheet: View {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool

    @State private var customName = ""
    @State private var customDurationMinutes = 25
    @State private var showCustom = false

    private let presets: [(name: String, icon: String, hex: String, minutes: Int?)] = [
        ("Focus Session", "brain.head.profile", "6C63FF", 25),
        ("Deep Work",     "bolt.fill",           "FF6B6B", 90),
        ("Meeting",       "person.2.fill",        "4EBF7A", 30),
        ("Break",         "cup.and.saucer.fill",  "FF9500", 15),
        ("Open Ended",    "clock",                "8E8E93", nil),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Start Activity")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 14)

            // Preset rows
            ForEach(presets, id: \.name) { p in
                PresetRow(name: p.name, icon: p.icon, hex: p.hex, minutes: p.minutes) {
                    addActivity(name: p.name, icon: p.icon, hex: p.hex, minutes: p.minutes)
                }
            }

            Divider()
                .opacity(0.15)
                .padding(.vertical, 8)

            // Custom section
            if showCustom {
                customSection
            } else {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showCustom = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.secondary)
                        Text("Custom…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(UNConstants.panelBackground)
    }

    @ViewBuilder
    private var customSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Activity name", text: $customName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))

            HStack {
                Text("Duration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $customDurationMinutes) {
                    Text("15 min").tag(15)
                    Text("25 min").tag(25)
                    Text("30 min").tag(30)
                    Text("45 min").tag(45)
                    Text("60 min").tag(60)
                    Text("90 min").tag(90)
                    Text("No limit").tag(0)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 100)
            }

            Button {
                let name = customName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                let mins: Int? = customDurationMinutes == 0 ? nil : customDurationMinutes
                addActivity(name: name, icon: "star.fill", hex: "5AC8FA", minutes: mins)
            } label: {
                Text("Start")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addActivity(name: String, icon: String, hex: String, minutes: Int?) {
        let end = minutes.map { Date().addingTimeInterval(Double($0) * 60) }
        let activity = LiveActivity(name: name, icon: icon, colorHex: hex, endDate: end)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            appState.liveActivities.append(activity)
        }
        isPresented = false
    }
}

// MARK: - Preset Row

private struct PresetRow: View {
    let name: String
    let icon: String
    let hex: String
    let minutes: Int?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(activityHex: hex).opacity(0.18))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(activityHex: hex))
                }
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                Spacer()
                if let m = minutes {
                    Text("\(m)m")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(isHovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeInOut(duration: 0.12)) { isHovering = h } }
    }
}

// MARK: - Settings View

struct LiveActivitiesSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Activities Settings")
                .font(.headline)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $state.showAmbientPill) {
                    Text("Show in notch area")
                        .font(.callout)
                        .foregroundStyle(.white)
                }
                .toggleStyle(.switch)
                Text("Display a compact pill in the notch when an activity is running.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.showAmbientPill {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notch pill displays")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $state.ambientPillDisplay) {
                        ForEach(AmbientPillDisplay.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

// MARK: - Color Helper

extension Color {
    /// Initialise from a 6-char hex string, e.g. "FF6B6B".
    /// Shared within the module — also used by AmbientActivityPill.
    init(activityHex hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF)         / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}
