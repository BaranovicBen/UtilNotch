import SwiftUI
import EventKit

// MARK: - Settings Keys

enum CalKey {
    static let lookahead       = "cal.lookaheadDays"     // Int: 1, 3, or 7
    static let enabledIDs      = "cal.enabledCalIDs"     // comma-joined calendar identifiers
    static let indicatorMode   = "cal.indicatorMode"     // "segmented" or "pills"
    static let enabledReminders = "cal.enabledReminderIDs" // comma-joined reminder-list identifiers
    static let weekStart       = "cal.weekStart"         // Int: 1 = Sunday, 2 = Monday
}

/// How per-day events are drawn under each day in the month grid.
enum CalendarIndicatorMode: String, CaseIterable, Identifiable {
    case segmented        // one rounded bar split into colored segments
    case pills            // a stack of thin colored pills
    var id: String { rawValue }
    var label: String {
        switch self {
        case .segmented: return "Segmented"
        case .pills:     return "Stacked pills"
        }
    }
}

enum CalLookahead: Int, CaseIterable, Identifiable {
    case today     = 1
    case threeDays = 3
    case week      = 7
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .today:     return "Today only"
        case .threeDays: return "3 days"
        case .week:      return "7 days"
        }
    }
}

// MARK: - Calendar View

struct CalendarView: View {
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var events: [EKEvent] = []
    @State private var allCalendars: [EKCalendar] = []
    @State private var isRequesting = false

    @AppStorage(CalKey.lookahead)  private var lookaheadDays: Int = 1
    @AppStorage(CalKey.enabledIDs) private var enabledIDsRaw: String = ""

    private var cal: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            // ── Header row ─────────────────────────────────────────
            HStack {
                Label("Calendar", systemImage: "calendar")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.bottom, 10)

            // ── Auth gate ──────────────────────────────────────────
            switch authStatus {
            case .fullAccess:
                authorizedContent
            case .notDetermined:
                permissionRequestView
            default:
                permissionDeniedView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            authStatus = EKEventStore.authorizationStatus(for: .event)
            if isAuthorized { loadCalendars(); loadEvents() }
        }
        .onChange(of: selectedDate)    { _, _ in loadEvents() }
        .onChange(of: lookaheadDays)   { _, _ in loadEvents() }
        .onChange(of: enabledIDsRaw)   { _, _ in loadEvents() }
    }

    // MARK: - Authorized Content

    @ViewBuilder
    private var authorizedContent: some View {
        VStack(spacing: 8) {
            dayHeader
            weekStrip
            eventsList
        }
    }

    // ── Day Header: ← large-day month/year → ──────────────────────
    private var dayHeader: some View {
        HStack(spacing: 10) {
            Button { shiftDay(-1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(dayNumberString)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(monthYearString)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { shiftDay(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    // ── Week Strip ──────────────────────────────────────────────────
    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                let isSelected = cal.isDate(day, inSameDayAs: selectedDate)
                let isToday    = cal.isDateInToday(day)
                Button { withAnimation(UNMotion.daySelect) { selectedDate = day } } label: {
                    VStack(spacing: 3) {
                        Text(dayLetter(day))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(isSelected ? .white : .secondary)
                        Text(dayNum(day))
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : (isToday ? Color.accentColor : .secondary))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.accentColor)
                        } else if isToday {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── Events List ─────────────────────────────────────────────────
    @ViewBuilder
    private var eventsList: some View {
        let shown = events.prefix(5)
        if shown.isEmpty {
            Spacer()
            Text("No upcoming events")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(Array(shown), id: \.eventIdentifier) { event in
                        EventRow(event: event)
                    }
                }
            }
        }
    }

    // MARK: - Permission Views

    private var permissionRequestView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Calendar Access")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            Text("Utility Notch needs calendar permission to show upcoming events.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Text("Manage access in Settings.")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundStyle(.red.opacity(0.7))
            Text("Calendar Access Denied")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
            Text("Open System Settings → Privacy & Security → Calendars and enable Utility Notch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Data Loading

    private var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    private func requestCalendarAccess() {
        isRequesting = true
        Task {
            do {
                if #available(macOS 14.0, *) {
                    try await sharedEventStore.requestFullAccessToEvents()
                } else {
                    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                        sharedEventStore.requestAccess(to: .event) { granted, error in
                            if granted { cont.resume() }
                            else { cont.resume(throwing: error ?? NSError(domain: "CalendarAccess", code: 1)) }
                        }
                    }
                }
                await MainActor.run {
                    authStatus = EKEventStore.authorizationStatus(for: .event)
                    isRequesting = false
                    loadCalendars()
                    loadEvents()
                }
            } catch {
                await MainActor.run {
                    authStatus = EKEventStore.authorizationStatus(for: .event)
                    isRequesting = false
                }
            }
        }
    }

    private func loadCalendars() {
        allCalendars = sharedEventStore.calendars(for: .event)
    }

    private func loadEvents() {
        guard isAuthorized else { return }

        let start = cal.startOfDay(for: selectedDate)
        let end   = cal.date(byAdding: .day, value: lookaheadDays, to: start) ?? start

        let enabledSet = enabledCalendarIDs
        let calendars: [EKCalendar]? = enabledSet.isEmpty
            ? nil
            : sharedEventStore.calendars(for: .event).filter { enabledSet.contains($0.calendarIdentifier) }

        let predicate = sharedEventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        let raw = sharedEventStore.events(matching: predicate)
        events = raw
            .filter { !$0.isAllDay || lookaheadDays > 1 }
            .sorted { $0.startDate < $1.startDate }
    }

    private var enabledCalendarIDs: Set<String> {
        Set(enabledIDsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    // MARK: - Date Helpers

    private func shiftDay(_ delta: Int) {
        if let d = cal.date(byAdding: .day, value: delta, to: selectedDate) {
            withAnimation(UNMotion.daySelect) { selectedDate = d }
        }
    }

    private var dayNumberString: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: selectedDate)
    }

    private var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }

    private var weekDays: [Date] {
        let weekday = cal.component(.weekday, from: selectedDate)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday - cal.firstWeekday), to: selectedDate) ?? selectedDate
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    private func dayNum(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: EKEvent
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            // Calendar color dot
            Circle()
                .fill(calColor)
                .frame(width: 7, height: 7)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    // Title
                    Text(event.title ?? "Untitled")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    // Video conference indicator
                    if hasVideoConference {
                        Image(systemName: "video.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Relative time badge ("in 2h") if within 6 hours
                    if let badge = relativeBadge {
                        Text(badge)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }

                // Time
                Text(timeString)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isHovering ? Color.white.opacity(0.04) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 7))
        .onHover { h in withAnimation(UNMotion.hover) { isHovering = h } }
    }

    private var calColor: Color {
        Color(nsColor: event.calendar.color ?? .systemBlue)
    }

    private var timeString: String {
        if event.isAllDay { return "All day" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: event.startDate)
    }

    private var hasVideoConference: Bool {
        func check(_ s: String?) -> Bool {
            guard let s = s?.lowercased() else { return false }
            return s.contains("zoom.us") || s.contains("meet.google") ||
                   s.contains("teams.microsoft") || s.contains("webex") ||
                   s.contains("meet.jit.si") || s.contains("facetime")
        }
        return check(event.url?.absoluteString) || check(event.notes)
    }

    private var relativeBadge: String? {
        guard !event.isAllDay else { return nil }
        let interval = event.startDate.timeIntervalSinceNow
        guard interval > 0 && interval < 6 * 3600 else { return nil }
        let hours   = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 { return "in \(hours)h" }
        return minutes <= 1 ? "now" : "in \(minutes)m"
    }
}

// MARK: - Settings View

struct CalendarSettingsView: View {
    @AppStorage(CalKey.lookahead)       private var lookaheadDays: Int = 3
    @AppStorage(CalKey.enabledIDs)      private var enabledIDsRaw: String = ""
    @AppStorage(CalKey.indicatorMode)   private var indicatorModeRaw: String = CalendarIndicatorMode.segmented.rawValue
    @AppStorage(CalKey.enabledReminders) private var enabledReminderIDsRaw: String = ""
    @AppStorage(CalKey.weekStart)       private var weekStartRaw: Int = Calendar.current.firstWeekday
    @State private var allCalendars: [EKCalendar] = []
    @State private var allReminderLists: [EKCalendar] = []

    private var indicatorMode: Binding<CalendarIndicatorMode> {
        Binding(
            get: { CalendarIndicatorMode(rawValue: indicatorModeRaw) ?? .segmented },
            set: { indicatorModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calendar Settings")
                .font(.headline)
                .foregroundStyle(.primary)

            // Event indicator style
            VStack(alignment: .leading, spacing: 6) {
                Text("Day event indicator")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: indicatorMode) {
                    ForEach(CalendarIndicatorMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Lookahead picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Event window")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $lookaheadDays) {
                    ForEach(CalLookahead.allCases) { opt in
                        Text(opt.label).tag(opt.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Week start
            VStack(alignment: .leading, spacing: 6) {
                Text("Start week on")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $weekStartRaw) {
                    Text("Monday").tag(2)
                    Text("Sunday").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 200)
            }

            // Calendar multi-select
            VStack(alignment: .leading, spacing: 6) {
                Text("Show calendars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if allCalendars.isEmpty {
                    Text("No calendars accessible.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(allCalendars, id: \.calendarIdentifier) { cal in
                        CalendarToggleRow(calendar: cal, enabledIDsRaw: $enabledIDsRaw, entity: .event)
                    }
                }
            }

            // Reminder-list multi-select
            VStack(alignment: .leading, spacing: 6) {
                Text("Include reminder lists")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if allReminderLists.isEmpty {
                    Text("No reminder lists accessible.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(allReminderLists, id: \.calendarIdentifier) { list in
                        CalendarToggleRow(calendar: list, enabledIDsRaw: $enabledReminderIDsRaw, entity: .reminder)
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .onAppear {
            if isAuthorized { allCalendars = sharedEventStore.calendars(for: .event) }
            if EKEventStore.authorizationStatus(for: .reminder) == .fullAccess {
                allReminderLists = sharedEventStore.calendars(for: .reminder)
            }
        }
    }

    private var isAuthorized: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        return s == .fullAccess
    }
}

private struct CalendarToggleRow: View {
    let calendar: EKCalendar
    @Binding var enabledIDsRaw: String
    var entity: EKEntityType = .event

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(nsColor: calendar.color ?? .systemBlue))
                .frame(width: 8, height: 8)
            Text(calendar.title)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { toggle($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
    }

    private var currentSet: Set<String> {
        Set(enabledIDsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private var isEnabled: Bool {
        let s = currentSet
        return s.isEmpty || s.contains(calendar.calendarIdentifier)  // empty = all enabled
    }

    private func toggle(_ on: Bool) {
        var set = currentSet
        if set.isEmpty {
            // All were enabled — explicitly enable all except this one if turning off
            let all = sharedEventStore.calendars(for: entity).map(\.calendarIdentifier)
            set = Set(all)
        }
        if on { set.insert(calendar.calendarIdentifier) }
        else  { set.remove(calendar.calendarIdentifier) }
        // If all are enabled again, clear to "show all"
        let allIDs = Set(sharedEventStore.calendars(for: entity).map(\.calendarIdentifier))
        enabledIDsRaw = set == allIDs ? "" : set.joined(separator: ",")
    }
}
