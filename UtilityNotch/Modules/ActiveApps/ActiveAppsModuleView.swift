import AppKit
import Darwin
import SwiftUI

// MARK: - View mode

enum ActiveAppsViewMode: String {
    case list
    case grid
}

// MARK: - Running app model

/// Synthetic row id for the aggregated "Other Processes" (OS / background) entry.
let kOtherProcessID = "__other_os__"

struct RunningApp: Identifiable {
    let id: String              // bundleIdentifier, or kOtherProcessID for the aggregate row
    let name: String
    let icon: NSImage
    let color: Color            // data-viz series color (palette by index)
    var ramBytes: Int64         // resident memory in bytes
    var isActive: Bool          // frontmost app
    let app: NSRunningApplication?   // nil for the synthetic "Other" row

    var isOther: Bool { id == kOtherProcessID }
}

// MARK: - RAM stats (host_statistics64 + sysctl swap)

struct RAMStats {
    var appGB: Double
    var wiredGB: Double
    var compressedGB: Double
    var freeGB: Double
    var swapGB: Double
    var totalGB: Double
    /// Real macOS memory-pressure level from `kern.memorystatus_vm_pressure_level` (1/2/4).
    var pressureRaw: Int32

    var usedGB: Double { appGB + wiredGB + compressedGB }
    var pressurePct: Double { min(100, usedGB / max(totalGB, 0.001) * 100) }

    enum PressureState {
        case normal, heavy, critical
        var label: String {
            switch self {
            case .normal:   "Normal"
            case .heavy:    "Heavy"
            case .critical: "Critical"
            }
        }
    }

    /// Mapped from the kernel pressure level (2 = warning, 4 = critical) — same mapping STATS uses.
    var pressureState: PressureState {
        switch pressureRaw {
        case 4:  .critical
        case 2:  .heavy
        default: .normal
        }
    }

    static func fetch() -> RAMStats {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        let toGB: (Double) -> Double = { $0 / 1_073_741_824 }
        let total = Double(ProcessInfo.processInfo.physicalMemory)

        guard result == KERN_SUCCESS else {
            return RAMStats(appGB: 0, wiredGB: 0, compressedGB: 0, freeGB: toGB(total),
                            swapGB: 0, totalGB: toGB(total), pressureRaw: 1)
        }
        let pageSize    = Double(vm_page_size)
        let active      = Double(vmStats.active_count)          * pageSize
        let inactive    = Double(vmStats.inactive_count)        * pageSize
        let speculative = Double(vmStats.speculative_count)     * pageSize
        let wired       = Double(vmStats.wire_count)            * pageSize
        let compressed  = Double(vmStats.compressor_page_count) * pageSize
        let purgeable   = Double(vmStats.purgeable_count)       * pageSize
        let external    = Double(vmStats.external_page_count)   * pageSize

        // STATS / Activity Monitor "Memory Used" — nets out purgeable + file-backed pages so cached
        // files don't inflate the figure the way (active + inactive) alone does.
        let used = active + inactive + speculative + wired + compressed - purgeable - external
        let app  = max(0, used - wired - compressed)
        let free = max(0, total - used)

        var xswUsage = xsw_usage()
        var xswSize  = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &xswUsage, &xswSize, nil, 0)
        let swapGB = toGB(Double(xswUsage.xsu_used))

        var level: Int32 = 1
        var levelSize = MemoryLayout<Int32>.size
        sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &levelSize, nil, 0)

        return RAMStats(
            appGB:        toGB(app),
            wiredGB:      toGB(wired),
            compressedGB: toGB(compressed),
            freeGB:       toGB(free),
            swapGB:       swapGB,
            totalGB:      toGB(total),
            pressureRaw:  level
        )
    }
}

// MARK: - Data-viz palette (per-app series colors, no single UNConstants token applies)

let kAppPalette: [Color] = [
    Color(red: 0.04, green: 0.52, blue: 1.00),   // blue
    Color(red: 0.19, green: 0.82, blue: 0.35),   // green
    Color(red: 0.75, green: 0.35, blue: 0.95),   // purple
    Color(red: 1.00, green: 0.62, blue: 0.04),   // orange
    Color(red: 1.00, green: 0.27, blue: 0.23),   // red
    Color(red: 0.35, green: 0.78, blue: 0.98),   // teal
    Color(red: 1.00, green: 0.22, blue: 0.37),   // pink
    Color(red: 1.00, green: 0.84, blue: 0.04),   // yellow
    Color(red: 0.39, green: 0.82, blue: 1.00),   // light blue
    Color(red: 0.64, green: 0.52, blue: 0.37),   // tan
    Color(red: 0.56, green: 0.56, blue: 0.58),   // gray
]

// MARK: - Module shell wrapper

struct ActiveAppsModuleView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var runningApps: [RunningApp] = []
    @State private var ramStats = RAMStats.fetch()
    @State private var viewMode = ActiveAppsViewMode.list
    @State private var hoveredID: String? = nil
    @State private var confirmQuitID: String? = nil
    @State private var refreshTimer: Timer?

    @AppStorage("activeApps.viewMode")    private var savedViewMode = "list"
    @AppStorage("activeApps.refreshRate") private var refreshRate = 3.0

    // Pressure colors resolve from the user's per-module palette (Settings → module colors).
    private var normalColor:   Color { appState.moduleColors.activeAppsNormal }
    private var heavyColor:    Color { appState.moduleColors.activeAppsHeavy }
    private var criticalColor: Color { appState.moduleColors.activeAppsCritical }

    private func pressureColor(_ state: RAMStats.PressureState) -> Color {
        switch state {
        case .normal:   normalColor
        case .heavy:    heavyColor
        case .critical: criticalColor
        }
    }

    private var frontmostName: String {
        runningApps.first(where: { $0.isActive })?.name ?? "—"
    }

    var body: some View {
        ModuleShellView(
            moduleTitle: "Active Apps",
            moduleIcon: "square.grid.2x2",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(reduceMotion ? UNMotion.reduced : UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: pressureColor(ramStats.pressureState),
            statusLeft: "\(runningApps.filter { !$0.isOther }.count) APPS · \(String(format: "%.1f", ramStats.appGB)) GB",
            statusRight: frontmostName.uppercased(),
            actionButton: nil
        ) {
            HStack(spacing: 0) {
                leftPane
                    .frame(width: 210)
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 1)
                rightPane
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            viewMode = ActiveAppsViewMode(rawValue: savedViewMode) ?? .list
            refreshData()
            startPolling()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
        .onChange(of: refreshRate) { _, _ in startPolling() }
    }

    // MARK: - Left pane

    private var leftPane: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            donutChart
            Spacer(minLength: 0)
            meterSection
            Spacer(minLength: 0)
            detailSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.015))
    }

    private var donutChart: some View {
        ZStack {
            DonutChartView(
                appGB: ramStats.appGB,
                wiredGB: ramStats.wiredGB,
                compGB: ramStats.compressedGB,
                freeGB: ramStats.freeGB,
                appColor: UNConstants.accentBlue,
                wiredColor: heavyColor,
                compColor: criticalColor
            )
            .frame(width: 112, height: 112)

            VStack(spacing: 1) {
                Text(String(format: "%.1f", ramStats.usedGB))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.93))
                    .monospacedDigit()
                Text("GB USED")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .tracking(0.6)
                Text("of \(Int(ramStats.totalGB.rounded())) GB")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.18))
            }
        }
    }

    private var meterSection: some View {
        VStack(spacing: 6) {
            SemicircleMeterView(
                fraction: ramStats.pressurePct / 100,
                tint: pressureColor(ramStats.pressureState)
            )
            .frame(width: 108, height: 30)

            HStack(spacing: 5) {
                Text(ramStats.pressureState.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pressureColor(ramStats.pressureState))
                Text("· \(Int(ramStats.pressurePct.rounded()))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
    }

    private var detailSection: some View {
        VStack(spacing: 4) {
            detailRow(color: UNConstants.accentBlue,    label: "Apps",       value: gb(ramStats.appGB))
            detailRow(color: heavyColor,                label: "Wired",      value: gb(ramStats.wiredGB))
            detailRow(color: criticalColor,             label: "Compressed", value: gb(ramStats.compressedGB))
            detailRow(color: Color.white.opacity(0.25), label: "Free",       value: gb(ramStats.freeGB))

            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)

            detailRow(color: kAppPalette[2], label: "Swap",
                      value: ramStats.swapGB < 0.01 ? "Zero KB" : gb(ramStats.swapGB))
        }
    }

    private func gb(_ v: Double) -> String { String(format: "%.1f GB", v) }

    private func detailRow(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 4, height: 4)
            Text(label.uppercased())
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.22))
                .tracking(0.3)
            Spacer()
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }

    // MARK: - Right pane

    private var rightPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Text(viewMode == .list ? "RUNNING · BY MEMORY" : "RAM USAGE · ALL APPS")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.30))
                    .tracking(0.5)
                Spacer()
                viewToggle
                refreshButton
            }
            .frame(height: 30)
            .padding(.horizontal, 14)

            if viewMode == .list {
                appListView
            } else {
                appGridView
            }
        }
    }

    private var viewToggle: some View {
        HStack(spacing: 2) {
            toggleBtn(icon: "list.bullet", mode: .list)
            toggleBtn(icon: "chart.bar",   mode: .grid)
        }
        .padding(2)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func toggleBtn(icon: String, mode: ActiveAppsViewMode) -> some View {
        let selected = viewMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { viewMode = mode }
            savedViewMode = mode.rawValue
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 22, height: 18)
                .background(selected ? Color.white.opacity(0.14) : Color.clear)
                .foregroundStyle(selected ? Color.white.opacity(0.85) : Color.white.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var refreshButton: some View {
        Button { refreshData() } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06))
                .foregroundStyle(Color.white.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.leading, 4)
    }

    // MARK: List

    private var appListView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            let sorted = runningApps.sorted { $0.ramBytes > $1.ramBytes }
            let maxBytes = sorted.first?.ramBytes ?? 1
            VStack(alignment: .leading, spacing: 2) {
                ForEach(sorted) { app in
                    appListRow(app: app, maxBytes: maxBytes)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func appListRow(app: RunningApp, maxBytes: Int64) -> some View {
        let barFraction = Double(app.ramBytes) / Double(max(maxBytes, 1))
        let ramGB       = Double(app.ramBytes) / 1_073_741_824
        let isHovered   = hoveredID == app.id
        let isConfirm   = confirmQuitID == app.id

        return Button {
            handleTap(app)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(app.color)
                    .frame(width: 3, height: 24)

                Image(nsImage: app.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.82))
                            .lineLimit(1)
                        if app.isActive {
                            Text("ACTIVE")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(normalColor)
                                .tracking(0.5)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule().fill(app.color)
                                .frame(width: geo.size.width * barFraction)
                        }
                    }
                    .frame(height: 3)
                }

                Spacer(minLength: 4)

                Text(String(format: "%.2f GB", ramGB))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .monospacedDigit()

                if isHovered && app.isOther {
                    Text("OPEN ▸")
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(UNConstants.accentBlue)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 5)
                        .background(UNConstants.accentBlue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .transition(.opacity)
                } else if isHovered {
                    Button {
                        if isConfirm {
                            forceQuit(app)
                            confirmQuitID = nil
                        } else {
                            confirmQuitID = app.id
                        }
                    } label: {
                        Text(isConfirm ? "CONFIRM" : "QUIT")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(UNConstants.destructiveRed)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 5)
                            .background(UNConstants.destructiveRed.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .frame(height: 36)
            .padding(.horizontal, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { over in
            hoveredID = over ? app.id : nil
            if !over { confirmQuitID = nil }
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // MARK: Grid

    private var appGridView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            let sorted = runningApps.sorted { $0.ramBytes > $1.ramBytes }
            let maxBytes = sorted.first?.ramBytes ?? 1
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 4), GridItem(.flexible(), spacing: 4)], spacing: 4) {
                ForEach(sorted) { app in
                    appGridCell(app: app, maxBytes: maxBytes)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func appGridCell(app: RunningApp, maxBytes: Int64) -> some View {
        let barFraction = Double(app.ramBytes) / Double(max(maxBytes, 1))
        let ramGB       = Double(app.ramBytes) / 1_073_741_824
        let pct         = Double(app.ramBytes) / (ramStats.totalGB * 1_073_741_824) * 100
        let isHovered   = hoveredID == app.id

        return Button {
            handleTap(app)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(nsImage: app.icon)
                        .resizable().scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(app.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.78))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    if app.isActive {
                        Circle().fill(normalColor).frame(width: 5, height: 5)
                    }
                }
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", ramGB))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .monospacedDigit()
                    Text(String(format: "GB · %.1f%%", pct))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(app.color)
                            .frame(width: geo.size.width * barFraction)
                    }
                }
                .frame(height: 3)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredID = $0 ? app.id : nil }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Data

    @MainActor
    private func refreshData() {
        ramStats = RAMStats.fetch()

        let workspace = NSWorkspace.shared
        let frontmost = workspace.frontmostApplication?.bundleIdentifier
        let selfBundle = Bundle.main.bundleIdentifier

        let raw = workspace.runningApplications.filter {
            $0.activationPolicy == .regular &&
            $0.localizedName?.isEmpty == false &&
            $0.bundleIdentifier != selfBundle
        }

        var apps: [RunningApp] = raw.enumerated().compactMap { idx, app in
            guard let name = app.localizedName else { return nil }
            let icon = app.icon ?? NSWorkspace.shared.icon(forFileType: "app")
            let bundleID = app.bundleIdentifier ?? "pid.\(app.processIdentifier)"
            return RunningApp(
                id: bundleID,
                name: name,
                icon: icon,
                color: kAppPalette[idx % kAppPalette.count],
                ramBytes: processMemory(pid: app.processIdentifier),
                isActive: bundleID == frontmost,
                app: app
            )
        }

        // "Other" — everything not shown above (OS daemons, agents, helpers = non-regular apps).
        // Aggregated into one entry; clicking it opens Activity Monitor for the full picture.
        let otherBytes = workspace.runningApplications
            .filter { $0.activationPolicy != .regular && $0.bundleIdentifier != selfBundle }
            .reduce(Int64(0)) { $0 + processMemory(pid: $1.processIdentifier) }
        apps.append(RunningApp(
            id: kOtherProcessID,
            name: "Other Processes",
            icon: NSWorkspace.shared.icon(forFile: Self.activityMonitorPath),
            color: Color.white.opacity(0.35),
            ramBytes: otherBytes,
            isActive: false,
            app: nil
        ))

        runningApps = apps
    }

    private static let activityMonitorPath = "/System/Applications/Utilities/Activity Monitor.app"

    private func processMemory(pid: pid_t) -> Int64 {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size))
        return result == Int32(size) ? Int64(info.pti_resident_size) : 0
    }

    /// Row click: focus a real app, or open Activity Monitor for the "Other" aggregate.
    @MainActor
    private func handleTap(_ app: RunningApp) {
        if app.isOther {
            openActivityMonitorMemory()
            return
        }
        app.app?.activate(options: [.activateAllWindows])
        refreshData()
    }

    /// Launch Activity Monitor and switch it to the Memory tab. Tab selection is best-effort UI
    /// scripting via System Events (needs Automation permission) — if denied, the app still opens
    /// on whatever tab it last showed.
    @MainActor
    private func openActivityMonitorMemory() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Self.activityMonitorPath))
        let script = """
        tell application "System Events"
            tell application process "Activity Monitor"
                repeat 30 times
                    if exists toolbar 1 of window 1 then exit repeat
                    delay 0.1
                end repeat
                try
                    click (first radio button of toolbar 1 of window 1 whose description is "Memory")
                end try
            end tell
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.4) {
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
        }
    }

    private func forceQuit(_ app: RunningApp) {
        app.app?.forceTerminate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task { @MainActor in refreshData() }
        }
    }

    private func startPolling() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: max(1, refreshRate), repeats: true) { _ in
            Task { @MainActor in refreshData() }
        }
    }
}

// MARK: - Donut chart

struct DonutChartView: View {
    let appGB: Double
    let wiredGB: Double
    let compGB: Double
    let freeGB: Double
    let appColor: Color
    let wiredColor: Color
    let compColor: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let R  = min(cx, cy) - 1
            let r  = R * 0.70

            struct Seg { var val: Double; var color: Color }
            // System memory breakdown — sums to total RAM (App + Wired + Compressed + Free).
            let segs: [Seg] = [
                Seg(val: appGB,   color: appColor),
                Seg(val: wiredGB, color: wiredColor),
                Seg(val: compGB,  color: compColor),
                Seg(val: freeGB,  color: Color.white.opacity(0.07)),
            ]

            let total = segs.reduce(0) { $0 + $1.val }
            guard total > 0 else { return }

            var startAngle = Angle.degrees(-90)
            for seg in segs {
                let sweep = Angle.degrees(360 * seg.val / total)
                if sweep.degrees < 0.2 { startAngle += sweep; continue }
                var path = Path()
                path.addArc(center: CGPoint(x: cx, y: cy), radius: R,
                            startAngle: startAngle, endAngle: startAngle + sweep, clockwise: false)
                path.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                            startAngle: startAngle + sweep, endAngle: startAngle, clockwise: true)
                path.closeSubpath()
                ctx.fill(path, with: .color(seg.color))
                startAngle += sweep
            }
        }
    }
}

// MARK: - Semicircle meter

/// Minimalist half-gauge (STATS-style): one thin track, one thin colored fill up to `fraction`, and
/// a small water-drop marker riding the arc at that point. No tick marks, zones, or letter labels.
struct SemicircleMeterView: View {
    let fraction: Double       // 0…1 pressure position
    let tint: Color

    private var f: Double { min(1, max(0, fraction)) }

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height - 2
            let R: CGFloat = min(cx - 6, cy - 6)
            let sw: CGFloat = 3

            // Track
            var track = Path()
            track.addArc(center: CGPoint(x: cx, y: cy), radius: R,
                         startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.stroke(track, with: .color(.white.opacity(0.08)),
                       style: StrokeStyle(lineWidth: sw, lineCap: .round))

            // Fill up to the current fraction
            if f > 0.001 {
                var fill = Path()
                fill.addArc(center: CGPoint(x: cx, y: cy), radius: R,
                            startAngle: .degrees(180), endAngle: .degrees(180 + f * 180), clockwise: false)
                ctx.stroke(fill, with: .color(tint),
                           style: StrokeStyle(lineWidth: sw, lineCap: .round))
            }

            // Water-drop marker at the tip of the fill.
            let ang = CGFloat(180 + f * 180) * .pi / 180
            let px = cx + R * cos(ang)
            let py = cy + R * sin(ang)
            drawDrop(ctx, center: CGPoint(x: px, y: py), radius: 4.2, pointAngle: ang, color: tint)
        }
    }

    /// A teardrop: a round bulb centered on the arc with a cusp pointing radially outward.
    private func drawDrop(_ ctx: GraphicsContext, center C: CGPoint, radius r: CGFloat,
                          pointAngle a: CGFloat, color: Color) {
        let tip = CGPoint(x: C.x + cos(a) * r * 2.2, y: C.y + sin(a) * r * 2.2)
        let leftA = a + .pi / 2
        let rightA = a - .pi / 2
        var p = Path()
        p.move(to: CGPoint(x: C.x + cos(leftA) * r, y: C.y + sin(leftA) * r))
        // Back half-circle (the round bulb), sweeping through the side opposite the tip.
        p.addArc(center: C, radius: r,
                 startAngle: .radians(Double(leftA)), endAngle: .radians(Double(rightA)),
                 clockwise: true)
        p.addLine(to: tip)
        p.closeSubpath()
        ctx.fill(p, with: .color(color))
    }
}
