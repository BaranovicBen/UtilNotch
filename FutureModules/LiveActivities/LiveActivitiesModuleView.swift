import SwiftUI

/// Live Activities module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/liveActivities.css
struct LiveActivitiesModuleView: View {
    @Environment(AppState.self) private var appState

    private struct Activity: Identifiable {
        let id = UUID()
        let name: String
        let category: String    // e.g. "FITNESS"
        let value: String       // e.g. "4.8 km"
        let progress: Double    // 0.0–1.0
        let accentColor: Color
        let iconSymbol: String
    }

    private let activities: [Activity] = [
        Activity(name: "Morning Run",   category: "FITNESS",   value: "4.8 km",   progress: 0.70, accentColor: Color(hex: "FF9F0A"), iconSymbol: "figure.run"),
        Activity(name: "Pizza Delivery",category: "FOOD",      value: "~25 min",  progress: 0.45, accentColor: Color(hex: "FF453A"), iconSymbol: "box.truck.fill"),
        Activity(name: "Xcode Build",   category: "DEVELOPER", value: "Build 14", progress: 0.85, accentColor: Color(hex: "0A84FF"), iconSymbol: "hammer.fill"),
    ]

    var body: some View {
        ModuleShellView(
            moduleTitle: "Live Activities",
            moduleIcon: "bolt.fill",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color(hex: "32D74B"),
            statusLeft: "3 ACTIVE",
            statusRight: "FROM IPHONE",
            actionButton: nil
        ) {
            // CSS: content gap 8px
            VStack(spacing: 8) {
                ForEach(activities) { activity in
                    activityCard(activity)
                }
            }
        }
    }

    // MARK: - Activity Card
    // CSS: padding 0px 12px, height 64px, bg rgba(255,255,255,0.03), radius 8px

    @ViewBuilder
    private func activityCard(_ activity: Activity) -> some View {
        HStack(spacing: 0) {
            // Left icon — CSS: 32×32 bg rgba(accent,0.15) radius 8px
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(activity.accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: activity.iconSymbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(activity.accentColor)
            }

            // App name + category — CSS: left-padded 12px from icon
            VStack(alignment: .leading, spacing: 0) {
                // CSS: Inter 500 14px #FFFFFF
                Text(activity.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                // CSS: JetBrains Mono 400 11px letter-spacing 1.1px uppercase rgba(255,255,255,0.5)
                Text(activity.category)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
                    .kerning(1.1)
                    .lineLimit(1)
            }
            .padding(.leading, 12)

            Spacer()

            // Right: value + progress bar
            // CSS: 128px wide, gap 6px
            VStack(alignment: .trailing, spacing: 6) {
                // Value — CSS: JetBrains Mono 400 12px #FFFFFF
                Text(activity.value)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white)

                // Progress bar — CSS: 128×3px bg rgba(255,255,255,0.1) radius 9999px
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 128, height: 3)

                    Capsule()
                        .fill(activity.accentColor)
                        .frame(width: 128 * activity.progress, height: 3)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
