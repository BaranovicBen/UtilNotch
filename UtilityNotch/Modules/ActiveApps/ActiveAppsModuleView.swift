import SwiftUI

/// Active Apps module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/ActiveApps.css
struct ActiveAppsModuleView: View {
    @Environment(AppState.self) private var appState

    private struct AppEntry: Identifiable {
        let id = UUID()
        let name: String
        let category: String
        let color: Color
        let memory: String
    }

    private let apps: [AppEntry] = [
        AppEntry(name: "Xcode",          category: "Developer Tools", color: Color(hex: "0A84FF"), memory: "1.2 GB"),
        AppEntry(name: "Figma",          category: "Design Tools",    color: Color(hex: "A259FF"), memory: "487 MB"),
        AppEntry(name: "Safari",         category: "Web Browser",     color: Color(hex: "0A84FF"), memory: "312 MB"),
        AppEntry(name: "Simulator",      category: "Developer Tools", color: Color(hex: "FF9F0A"), memory: "891 MB"),
        AppEntry(name: "Terminal",       category: "Developer Tools", color: Color(hex: "30D158"), memory: "48 MB"),
        AppEntry(name: "Utility Notch",  category: "Utilities",       color: Color(hex: "636366"), memory: "22 MB"),
    ]

    var body: some View {
        ModuleShellView(
            moduleTitle: "Active Apps",
            moduleIcon: "square.grid.2x2",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: Color(hex: "32D74B"),
            statusLeft: "8 APPS RUNNING",
            statusRight: "CLICK ROW TO FORCE QUIT",
            actionButton: nil
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(apps) { app in
                        appRow(app)
                    }
                }
            }
        }
    }

    // MARK: - App Row
    // CSS: padding 10px 12px, height 56px, bg rgba(255,255,255,0.03), radius 8px

    @ViewBuilder
    private func appRow(_ app: AppEntry) -> some View {
        HStack(spacing: 0) {
            // App icon placeholder — 28×28 colored RoundedRect, right margin 12px
            // CSS: background <color>, border-radius 8px, width 28px, height 28px
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(app.color)
                .frame(width: 28, height: 28)
                .padding(.trailing, 12)

            // App name + category label
            VStack(alignment: .leading, spacing: 0) {
                // CSS: Inter 600 14px rgba(255,255,255,0.85)
                Text(app.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                // CSS: JetBrains Mono 400 10px letter-spacing 0.5px uppercase rgba(255,255,255,0.4)
                Text(app.category.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .kerning(0.5)
                    .lineLimit(1)
            }

            Spacer()

            // Memory badge — CSS: JetBrains Mono 400 12px rgba(255,255,255,0.7) right-padded 16px
            Text(app.memory)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.7))
                .padding(.trailing, 16)

            // QUIT button — CSS: padding 4px 12px, radius 9999px, JetBrains Mono bold 10px, color #FF453A
            Text("QUIT")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "FF453A"))
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Color(hex: "FF453A").opacity(0.1))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
