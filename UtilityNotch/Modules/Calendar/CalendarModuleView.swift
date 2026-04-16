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

    // Dummy events shown when permission is not yet granted
    private let dummyEvents: [CalEvent] = [
        CalEvent(time: "09:00", title: "Team Standup",     accentColor: Color(hex: "42E355"), hasVideo: true),
        CalEvent(time: "14:00", title: "Design Review",    accentColor: Color(hex: "0A84FF"), hasVideo: true),
        CalEvent(time: "16:30", title: "1:1 with Manager", accentColor: Color(hex: "A259FF"), hasVideo: false),
    ]

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

    private var dateRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text(currentDayNumber)
                .font(.system(size: 52, weight: .black))
                .foregroundStyle(Color.white)
                .padding(.leading, 8)

            Text(currentMonthYear)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.70))
                .padding(.bottom, 4)

            Spacer()

            HStack(spacing: 8) {
                navButton(icon: "chevron.left")  { shiftDay(-7) }
                navButton(icon: "chevron.right") { shiftDay(7) }
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
        }
        .buttonStyle(.plain)
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
        .frame(height: 52)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func weekDayCell(_ day: WeekDay) -> some View {
        ZStack {
            if day.isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(day.isToday ? Color(hex: "0A84FF") : Color.white.opacity(0.12))
                    .frame(width: 44, height: 40)
            }

            VStack(spacing: 3) {
                Text(day.abbrev)
                    .font(.system(size: 10, weight: day.isSelected ? .medium : .regular))
                    .foregroundStyle(day.isSelected ? Color.white : Color.white.opacity(0.30))

                Text("\(day.day)")
                    .font(.system(size: 13, weight: day.isSelected ? .semibold : .regular))
                    .foregroundStyle(day.isSelected ? Color.white : Color.white.opacity(0.35))
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

    // MARK: - Navigation

    private func shiftDay(_ delta: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
        loadEvents()
    }

    private func selectDay(_ date: Date) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
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
    }
}
