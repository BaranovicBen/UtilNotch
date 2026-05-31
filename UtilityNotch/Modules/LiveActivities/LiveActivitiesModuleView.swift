import SwiftUI

struct LiveActivitiesModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortedActivities: [LiveActivity] {
        appState.liveActivities.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.timestamp > $1.timestamp
        }
    }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Live Activities",
            moduleIcon: "clock.badge.checkmark",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: sortedActivities.isEmpty ? Color.white.opacity(0.2) : UNConstants.successGreen,
            statusLeft: "\(sortedActivities.count) CURRENT",
            statusRight: sortedActivities.first?.destinationModuleID.uppercased() ?? "LOCAL",
            actionButton: nil
        ) {
            Group {
                if sortedActivities.isEmpty {
                    emptyState
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(sortedActivities) { activity in
                                LiveActivityRow(activity: activity) {
                                    withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                                        appState.selectModule(activity.destinationModuleID)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(UNConstants.textTertiary)
            Text("Nothing active")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UNConstants.textPrimary)
            Text("Downloads, conversion work, music, and upcoming events can surface here when they matter.")
                .font(.system(size: 12))
                .foregroundStyle(UNConstants.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 36)
    }
}

private struct LiveActivityRow: View {
    let activity: LiveActivity
    let onOpen: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(activityColor.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: activity.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(activityColor.opacity(0.9))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UNConstants.textPrimary)
                        .lineLimit(1)
                    Text(activity.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(UNConstants.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 5) {
                    Text(Self.relativeString(from: activity.timestamp))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(UNConstants.textTertiary)

                    if let progress = activity.progress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(activityColor)
                            .frame(width: 92)
                    } else {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(UNConstants.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                    .fill(isHovering ? UNConstants.rowHoverSurface : UNConstants.rowSurface)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.hover) {
                isHovering = hovering
            }
        }
    }

    private var activityColor: Color {
        switch activity.destinationModuleID {
        case "downloads": return UNConstants.fileAudioEnd
        case "fileConverter": return UNConstants.fileVideoEnd
        case "musicControl": return UNConstants.musicProgressStart
        case "calendar": return UNConstants.accentBlue
        default: return UNConstants.fileDefaultEnd
        }
    }

    private static func relativeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date()).uppercased()
    }
}
