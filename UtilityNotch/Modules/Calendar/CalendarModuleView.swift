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

    private var isAuthorized: Bool {
        if #available(macOS 14.0, *) { return authStatus == .fullAccess }
        return authStatus == .authorized
    }

    // MARK: - Display models

    private struct WeekDay {
        let abbrev: String
        let day: Int
        let isToday: Bool
    }

    private struct CalEvent: Identifiable {
        let id = UUID()
        let time: String
        let title: String
        let accentColor: Color
        let hasVideo: Bool
    }

    // Dummy events shown when permission is not yet granted
    private let dummyEvents: [CalEvent] = [
        CalEvent(time: "09:00", title: "Team Standup",     accentColor: Color(hex: "42E355"), hasVideo: true),
        CalEvent(time: "14:00", title: "Design Review",    accentColor: Color(hex: "0A84FF"), hasVideo: true),
        CalEvent(time: "16:30", title: "1:1 with Manager", accentColor: Color(hex: "A259FF"), hasVideo: false),
    ]

    // MARK: - Computed real-date values

    private var currentWeekDays: [WeekDay] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let firstWeekday = cal.firstWeekday
        let offset = (weekday - firstWeekday + 7) % 7
        guard let startOfWeek = cal.date(byAdding: .day, value: -offset, to: today) else { return [] }
        let abbrevs = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
        return (0..<7).compactMap { i -> WeekDay? in
            guard let date = cal.date(byAdding: .day, value: i, to: startOfWeek) else { return nil }
            let dayNum = cal.component(.day, from: date)
            let wdIndex = cal.component(.weekday, from: date) - 1
            return WeekDay(abbrev: abbrevs[wdIndex], day: dayNum, isToday: cal.isDateInToday(date))
        }
    }

    private var currentDayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: Date())
    }

    private var currentMonthYear: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: Date())
    }

    private var displayEvents: [CalEvent] {
        if isAuthorized {
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
        return dummyEvents
    }

    // MARK: - Body

    var body: some View {
        ModuleShellView(
            moduleTitle: "Calendar",
            moduleIcon: "calendar",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(.spring(duration: 0.28, bounce: 0.16)) {
                    appState.selectModule(id)
                }
            },
            statusDotColor: isAuthorized ? Color(hex: "32D74B") : Color.white.opacity(0.2),
            statusLeft: isAuthorized ? currentMonthYear.uppercased() : "PERMISSION REQUIRED",
            statusRight: isAuthorized ? "\(displayEvents.count) UPCOMING" : "DEMO DATA",
            actionButton: nil
        ) {
            // ScrollView ensures the content never pushes the footer out of position.
            // The scroll view fills the content slot exactly (via maxHeight: .infinity).
            // Content scrolls internally if it overflows — the shell never grows.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    dateRow
                    weekStrip
                    upcomingLabel
                    eventRows
                }
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if isAuthorized { loadEvents() }
        }
    }

    // MARK: - Date Row
    // Total height: 40pt. Top padding: 12pt.
    // Running total after: 12 + 40 = 52pt

    private var dateRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(currentDayNumber)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)

            Text(currentMonthYear)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.leading, 8)
                .padding(.bottom, 3)

            Spacer()

            HStack(spacing: 8) {
                navButton(icon: "chevron.left")
                navButton(icon: "chevron.right")
            }
        }
        .frame(height: 40)
    }

    @ViewBuilder
    private func navButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.5))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
    }

    // MARK: - Week Strip
    // Top gap: 8pt. Height: 52pt.
    // Running total after: 52 + 8 + 52 = 112pt

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(currentWeekDays, id: \.day) { day in
                weekDayCell(day)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func weekDayCell(_ day: WeekDay) -> some View {
        ZStack {
            if day.isToday {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(hex: "0A84FF"))
                    .frame(width: 44, height: 40)
            }

            VStack(spacing: 3) {
                Text(day.abbrev)
                    .font(.system(size: 10, weight: day.isToday ? .medium : .regular))
                    .foregroundStyle(day.isToday ? Color.white : Color.white.opacity(0.30))

                Text("\(day.day)")
                    .font(.system(size: 13, weight: day.isToday ? .semibold : .regular))
                    .foregroundStyle(day.isToday ? Color.white : Color.white.opacity(0.35))
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
            .foregroundStyle(Color.white.opacity(0.25))
            .frame(height: 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 6)
    }

    // MARK: - Event Rows
    // 3 rows × 44pt + 2 gaps × 6pt = 132 + 12 = 144pt
    // Running total: 142 + 144 = 286pt ✓ fits in 296pt

    private var eventRows: some View {
        VStack(spacing: 6) {
            ForEach(displayEvents) { event in
                eventRow(event)
                    .frame(height: 44)
            }
        }
    }

    @ViewBuilder
    private func eventRow(_ event: CalEvent) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .frame(height: 44)

            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(event.accentColor)
                    .frame(width: 3, height: 20)
                    .padding(.leading, 12)

                Text(event.time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.leading, 10)

                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)
                    .padding(.leading, 10)

                Spacer()

                if event.hasVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .padding(.trailing, 12)
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadEvents() {
        guard isAuthorized else { return }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 7, to: start) ?? start
        let predicate = sharedEventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        ekEvents = sharedEventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { $0 }
    }
}
