import AppKit
import SwiftUI
import EventKit

/// Calendar module — full-shell Figma implementation with EventKit integration.
/// Shows real events when authorized; falls back to dummy data with PERMISSION REQUIRED footer.
/// CSS source: /DesignReference/Css/calendar.css
struct CalendarModuleView: View {
    @Environment(AppState.self) private var appState

    // MARK: - Auth state
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var ekEvents: [EKEvent] = []
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var isRequestingAccess = false

    private var isAuthorized: Bool {
        return authStatus == .fullAccess
    }

    // MARK: - Display models

    private struct WeekDay {
        let abbrev: String
        let day: Int
        let date: Date
        let isToday: Bool
        let isSelected: Bool
    }

    private struct CalEvent: Identifiable {
        let id = UUID()
        let time: String
        let title: String
        let accentColor: Color
        let hasVideo: Bool
    }

    // MARK: - Computed real-date values

    private var currentWeekDays: [WeekDay] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        let firstWeekday = cal.firstWeekday
        let offset = (weekday - firstWeekday + 7) % 7
        guard let startOfWeek = cal.date(byAdding: .day, value: -offset, to: selectedDate) else { return [] }
        let abbrevs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return (0..<7).compactMap { i -> WeekDay? in
            guard let date = cal.date(byAdding: .day, value: i, to: startOfWeek) else { return nil }
            let dayNum = cal.component(.day, from: date)
            let wdIndex = cal.component(.weekday, from: date) - 1
            return WeekDay(
                abbrev: abbrevs[wdIndex],
                day: dayNum,
                date: date,
                isToday: cal.isDateInToday(date),
                isSelected: cal.isDate(date, inSameDayAs: selectedDate)
            )
        }
    }

    private var currentDayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: selectedDate)
    }

    private var currentMonthYear: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }

    private var displayEvents: [CalEvent] {
        guard isAuthorized else { return [] }
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm"
        return ekEvents.prefix(3).map { event in
            CalEvent(
                time: event.isAllDay ? "All day" : formatter.string(from: event.startDate),
                title: event.title ?? "Untitled",
                accentColor: Color(nsColor: event.calendar.color ?? .systemBlue),
                hasVideo: false
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ModuleShellView(
            moduleTitle: "Calendar",
            moduleIcon: "calendar",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(UNMotion.moduleSwitch) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: isAuthorized ? UNConstants.successGreen : Color.white.opacity(0.2),
            statusLeft: isAuthorized ? currentMonthYear.uppercased() : "PERMISSION REQUIRED",
            statusRight: isAuthorized ? "\(displayEvents.count) UPCOMING" : "ALLOW ACCESS",
            actionButton: nil
        ) {
            if isAuthorized {
                HStack(alignment: .top, spacing: UNConstants.moduleColumnGap) {
                    dateRow
                        .frame(width: 128)
                        .frame(maxHeight: .infinity)

                    VStack(alignment: .leading, spacing: UNConstants.moduleRowGap) {
                        weekStrip
                        upcomingLabel
                        eventRows
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                permissionCTA
            }
        }
        .onAppear {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if isAuthorized { loadEvents() }
            else { removeCalendarActivity() }
        }
    }

    private var permissionCTA: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(UNConstants.textSecondary)

            VStack(spacing: 5) {
                Text("Allow Calendar Access")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)

                Text("urNotch reads your local calendars to show upcoming events in the shelf. Nothing leaves this Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(UNConstants.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: 330)

            HStack(spacing: 8) {
                Button {
                    requestCalendarAccess()
                } label: {
                    HStack(spacing: 6) {
                        if isRequestingAccess {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.62)
                        }
                        Text(isRequestingAccess ? "Requesting..." : "Allow Calendar Access")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: UNConstants.compactControlHeight)
                    .background(
                        Capsule()
                            .fill(UNConstants.controlSurface)
                    )
                }
                .buttonStyle(.pressFeedback)
                .disabled(isRequestingAccess)

                if authStatus == .denied || authStatus == .restricted {
                    Button {
                        openCalendarPrivacySettings()
                    } label: {
                        Text("Open Settings")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(UNConstants.textSecondary)
                            .padding(.horizontal, 12)
                            .frame(height: UNConstants.compactControlHeight)
                            .background(
                                Capsule()
                                    .fill(UNConstants.insetSurface)
                            )
                    }
                    .buttonStyle(.pressFeedback)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }

    // MARK: - Date Row

    private var dateRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(currentMonthYear)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textSecondary)
                    .lineLimit(2)

                Text(currentDayNumber)
                    .font(.system(size: 58, weight: .black))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                navButton(icon: "chevron.left")  { shiftDay(-7) }
                navButton(icon: "chevron.right") { shiftDay(7) }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(UNConstants.insetSurface)
        }
    }

    @ViewBuilder
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(UNConstants.textSecondary)
                .frame(width: UNConstants.hudButtonSize, height: UNConstants.hudButtonSize)
                .background(
                    Circle()
                        .fill(UNConstants.controlSurface)
                )
        }
        .buttonStyle(.pressFeedback)
    }

    // MARK: - Week Strip
    // Top gap: 8pt. Height: 52pt.
    // Running total after: 52 + 8 + 52 = 112pt

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(currentWeekDays, id: \.day) { day in
                Button { selectDay(day.date) } label: {
                    weekDayCell(day)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background {
            RoundedRectangle(cornerRadius: UNConstants.tileCornerRadius, style: .continuous)
                .fill(UNConstants.insetSurface)
        }
    }

    @ViewBuilder
    private func weekDayCell(_ day: WeekDay) -> some View {
        ZStack {
            if day.isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(day.isToday ? UNConstants.accentBlue : UNConstants.selectedSurface)
                    .frame(width: 42, height: 44)
            }

            VStack(spacing: 3) {
                Text(day.abbrev)
                    .font(.system(size: 10, weight: day.isSelected ? .medium : .regular))
                    .foregroundStyle(day.isSelected ? Color.white : UNConstants.textMuted)

                Text("\(day.day)")
                    .font(.system(size: 13, weight: day.isSelected ? .semibold : .regular))
                    .foregroundStyle(day.isSelected ? Color.white : UNConstants.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    // MARK: - Upcoming Label
    // Top gap: 8pt. Height: 16pt. Bottom gap: 6pt.
    // Running total after: 112 + 8 + 16 + 6 = 142pt

    private var upcomingLabel: some View {
        Text("UPCOMING")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(UNConstants.textTertiary)
            .frame(height: 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Event Rows
    // 3 rows × 44pt + 2 gaps × 6pt = 132 + 12 = 144pt
    // Running total: 142 + 144 = 286pt ✓ fits in 296pt

    private var eventRows: some View {
        VStack(spacing: 6) {
            ForEach(displayEvents) { event in
                eventRow(event)
                    .frame(height: 46)
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ event: CalEvent) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(UNConstants.rowSurface)
                .frame(height: 46)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(event.accentColor)
                    .frame(width: 3, height: 20)
                    .padding(.leading, 12)

                Text(event.time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(UNConstants.textSecondary)
                    .padding(.leading, 10)

                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(1)
                    .padding(.leading, 10)

                Spacer()

                if event.hasVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(UNConstants.textTertiary)
                        .padding(.trailing, 12)
                }
            }
        }
    }

    // MARK: - Navigation

    private func shiftDay(_ delta: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        withAnimation(UNMotion.daySelect) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
        loadEvents()
    }

    private func selectDay(_ date: Date) {
        withAnimation(UNMotion.daySelect) {
            selectedDate = Calendar.current.startOfDay(for: date)
        }
        loadEvents()
    }

    // MARK: - Data Loading

    private func loadEvents() {
        guard isAuthorized else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        let predicate = sharedEventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        ekEvents = sharedEventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { $0 }
        updateCalendarActivity()
    }

    private func requestCalendarAccess() {
        guard !isRequestingAccess else { return }
        if authStatus == .denied || authStatus == .restricted {
            openCalendarPrivacySettings()
            return
        }

        isRequestingAccess = true
        Task {
            do {
                _ = try await sharedEventStore.requestFullAccessToEvents()
            } catch {
                #if DEBUG
                print("Calendar permission request failed: \(error)")
                #endif
            }
            await MainActor.run {
                authStatus = EKEventStore.authorizationStatus(for: .event)
                isRequestingAccess = false
                if isAuthorized { loadEvents() }
                else { removeCalendarActivity() }
            }
        }
    }

    @MainActor
    private func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    private func updateCalendarActivity() {
        removeCalendarActivity()
        guard let next = ekEvents.first(where: { $0.startDate >= Date() }) else { return }
        appState.liveActivities.append(
            LiveActivity(
                title: "Next event",
                subtitle: next.title ?? "Calendar event",
                icon: "calendar",
                progress: nil,
                priority: 35,
                timestamp: next.startDate,
                destinationModuleID: "calendar"
            )
        )
    }

    @MainActor
    private func removeCalendarActivity() {
        appState.liveActivities.removeAll {
            $0.destinationModuleID == "calendar" && $0.icon == "calendar"
        }
    }
}
