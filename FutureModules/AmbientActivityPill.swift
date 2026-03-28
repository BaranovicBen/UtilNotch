import AppKit
import SwiftUI

// MARK: - Controller

/// Always-on ambient pill window that sits in the physical notch area of the screen.
/// Shows the most-recently-started live activity when the panel is closed.
///
/// // LIVEACTIVITY_NOTE: True cross-window matchedGeometryEffect is not supported on macOS.
/// The visual handoff is achieved by coordinating fade timing:
///   • Panel opens  → pill fades out (opacity 1 → 0, 0.15 s)
///   • Panel closes → pill fades in  (opacity 0 → 1, 0.20 s, after a short delay)
/// Inside the panel, ActivityCard springs in from scale 0.88 to imply the pill expanded into it.
@MainActor
final class AmbientPillController {

    private var window: NSWindow?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        createWindow()
        startObserving()
        updateVisibility()
    }

    func uninstall() {
        window?.orderOut(nil)
        window = nil
    }

    // MARK: - Private

    private func createWindow() {
        guard let screen = NSScreen.main else { return }
        let pillW: CGFloat = 180
        let pillH: CGFloat = 30
        let x = screen.frame.midX - pillW / 2
        let y = screen.frame.maxY - pillH    // top edge of screen (over notch)

        let win = NSWindow(
            contentRect: NSRect(x: x, y: y, width: pillW, height: pillH),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Level: just below the screen saver so it stays above normal app windows.
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        win.isMovableByWindowBackground = false
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.alphaValue = 0

        let hosting = NSHostingView(rootView: AmbientPillView().environment(appState))
        hosting.frame = win.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        win.contentView?.addSubview(hosting)

        self.window = win
    }

    private func startObserving() {
        func observe() {
            withObservationTracking {
                _ = appState.isPanelVisible
                _ = appState.liveActivities
                _ = appState.showAmbientPill
            } onChange: { [weak self] in
                Task { @MainActor in
                    self?.updateVisibility()
                    observe()
                }
            }
        }
        observe()
    }

    private func updateVisibility() {
        let shouldShow = appState.showAmbientPill
            && !appState.liveActivities.isEmpty
            && !appState.isPanelVisible

        guard let win = window else { return }

        if shouldShow && !win.isVisible {
            win.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                win.animator().alphaValue = 1
            }
        } else if !shouldShow && win.isVisible {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                win.animator().alphaValue = 0
            }, completionHandler: {
                win.orderOut(nil)
            })
        }
    }
}

// MARK: - Pill SwiftUI View

private struct AmbientPillView: View {
    @Environment(AppState.self) private var appState
    @State private var now: Date = .init()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var activity: LiveActivity? { appState.liveActivities.last }

    var body: some View {
        ZStack {
            if let act = activity {
                HStack(spacing: 5) {
                    Image(systemName: act.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(activityHex: act.colorHex))
                    Text(pillText(for: act))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.black.opacity(0.72), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(ticker) { now = $0 }
    }

    private func pillText(for act: LiveActivity) -> String {
        switch appState.ambientPillDisplay {
        case .name:
            let n = act.name
            return n.count > 16 ? String(n.prefix(15)) + "…" : n
        case .elapsedTime:
            return formatDuration(now.timeIntervalSince(act.startDate))
        case .remainingTime:
            guard let end = act.endDate else {
                return formatDuration(now.timeIntervalSince(act.startDate))
            }
            let rem = max(0, end.timeIntervalSince(now))
            return rem == 0 ? "Done" : formatDuration(rem)
        }
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

// Color(activityHex:) is defined in LiveActivitiesView.swift (same module).
