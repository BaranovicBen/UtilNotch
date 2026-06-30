import AppKit
import SwiftUI
import EventKit

/// Calendar module — redesigned: a compact month grid with per-day event indicators on the left
/// (segmented bar or stacked pills, switchable in module settings) and a "today at a glance"
/// strip + reminders/upcoming list on the right. EventKit-backed via `sharedEventStore`.
struct CalendarModuleView: View {
    @Environment(AppState.self) private var appState

    // MARK: - Auth & data
    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var remindersAuthStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    @State private var ekEvents: [EKEvent] = []                 // lookahead window → right-side list
    @State private var eventsByDay: [Date: [EKEvent]] = [:]     // visible month → grid indicators
    @State private var todayReminders: [EKReminder] = []
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    @State private var isRequestingAccess = false

    @AppStorage(CalKey.indicatorMode) private var indicatorModeRaw: String = CalendarIndicatorMode.segmented.rawValue
    private var indicatorMode: CalendarIndicatorMode {
        CalendarIndicatorMode(rawValue: indicatorModeRaw) ?? .segmented
    }

    /// How many days ahead the upcoming list covers (1 = today only … up to 7). Set in settings.
    @AppStorage(CalKey.lookahead) private var lookaheadDays: Int = 3

    /// Which reminder lists to include (comma-joined identifiers; empty = all). Set in settings.
    @AppStorage(CalKey.enabledReminders) private var enabledReminderIDsRaw: String = ""

    /// First day of the week — 1 = Sunday, 2 = Monday. Set in settings.
    @AppStorage(CalKey.weekStart) private var weekStartRaw: Int = Calendar.current.firstWeekday

    /// Shared 7-column layout so the weekday header lines up exactly with the day grid.
    private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    /// Calendar honoring the user's week-start preference.
    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = (weekStartRaw == 1 || weekStartRaw == 2) ? weekStartRaw : c.firstWeekday
        return c
    }
    private var isAuthorized: Bool { authStatus == .fullAccess }

    // MARK: - Display models

    private struct MonthDay: Identifiable {
        let id: Date
        let date: Date
        let number: Int
        let isInMonth: Bool
        let isToday: Bool
        let isSelected: Bool
        let isWeekend: Bool
    }

    // MARK: - Body

    var body: some View {
        ModuleShellView(
            moduleTitle: "Calendar",
            moduleIcon: "calendar",
            modules: shellNavItems(appState: appState),
            activeModuleID: appState.activeModuleID,
            onModuleSelect: { id in
                withAnimation(UNMotion.moduleSwitch) { appState.selectModule(id) }
            },
            statusDotColor: isAuthorized ? UNConstants.successGreen : Color.white.opacity(0.2),
            statusLeft: isAuthorized ? currentMonthYear.uppercased() : "PERMISSION REQUIRED",
            statusRight: isAuthorized ? "\(ekEvents.count) UPCOMING" : "OPEN SETTINGS",
            actionButton: nil
        ) {
            if isAuthorized {
                HStack(spacing: 0) {
                    miniCalendar
                        .frame(width: 238)
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                    eventsList
                        .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                permissionCTA
            }
        }
        .onAppear { refreshAll() }
        .onChange(of: lookaheadDays) { _, _ in loadEvents() }
        .onChange(of: weekStartRaw) { _, _ in loadMonthEvents() }
        .onChange(of: enabledReminderIDsRaw) { _, _ in loadTodayReminders() }
    }

    // MARK: - Mini Calendar (left)

    private var miniCalendar: some View {
        VStack(spacing: 8) {
            monthNavRow
            VStack(spacing: 3) {       // weekday letters sit right above the grid
                dowHeader
                calGrid
            }
        }
        .padding(.trailing, 14)
    }

    private var monthNavRow: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(monthTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UNConstants.textPrimary)
                    .lineLimit(1)
                Text(yearTitle)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                navButton(icon: "chevron.left") { shiftMonth(-1) }
                navButton(icon: "chevron.right") { shiftMonth(1) }
            }
        }
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(UNConstants.textSecondary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(UNConstants.controlSurface))
        }
        .buttonStyle(.pressFeedback)
    }

    private var dowHeader: some View {
        LazyVGrid(columns: gridColumns, spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, sym in
                Text(sym)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
            }
        }
    }

    private var calGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 3) {
            ForEach(monthDays) { day in
                Button { selectDay(day.date) } label: {
                    dayCell(day)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func dayCell(_ day: MonthDay) -> some View {
        let colors = calendarColors(for: eventsByDay[day.date] ?? [])
        return VStack(spacing: 1) {
            ZStack {
                if day.isToday {
                    Circle().fill(UNConstants.destructiveRed).frame(width: 18, height: 18)
                } else if day.isSelected {
                    Circle().fill(UNConstants.accentBlue.opacity(0.20)).frame(width: 15, height: 15)
                }
                Text("\(day.number)")
                    .font(.system(size: 10, weight: day.isToday ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(dayNumberColor(day))
            }
            .frame(width: 16, height: 16)

            // Event indicator (or a spacer to keep rows aligned)
            Group {
                if !colors.isEmpty {
                    eventIndicator(colors: colors).opacity(day.isInMonth ? 1 : 0.35)
                } else {
                    Color.clear.frame(height: 5)
                }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Event indicators

    @ViewBuilder
    private func eventIndicator(colors: [Color]) -> some View {
        switch indicatorMode {
        case .segmented: segmentedPill(colors: colors)
        case .pills:     pillStack(colors: colors)
        }
    }

    /// One rounded bar split into up to 4 calendar-colored segments. Single event = a dot.
    private func segmentedPill(colors: [Color]) -> some View {
        let cols = Array(colors.prefix(4))
        let n = max(1, cols.count)
        let h: CGFloat = 5
        let w: CGFloat = n == 1 ? h : min(20, h + CGFloat(n - 1) * 6)
        return HStack(spacing: 0) {
            ForEach(cols.indices, id: \.self) { i in
                cols[i].frame(width: w / CGFloat(n), height: h)
            }
        }
        .frame(width: w, height: h)
        .clipShape(Capsule())
    }

    /// Stacked thin pills — one per calendar color (up to 3).
    private func pillStack(colors: [Color]) -> some View {
        VStack(spacing: 1.5) {
            ForEach(Array(colors.prefix(3)).indices, id: \.self) { i in
                colors[i].frame(width: 14, height: 2.5).clipShape(Capsule())
            }
        }
    }

    // MARK: - Events list (right)

    private var eventsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            todayStrip
                .padding(.horizontal, 14)
                .padding(.bottom, 8)

            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    remindersSection
                    upcomingSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
        }
        .padding(.leading, 12)
    }

    private var todayStrip: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date().formatted(.dateTime.weekday(.abbreviated)).uppercased())
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
                Text(Date().formatted(.dateTime.day()))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(UNConstants.textPrimary)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Today at a glance")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(UNConstants.textTertiary)
                    .textCase(.uppercase)
                HStack(spacing: 6) {
                    glancePill(color: UNConstants.accentBlue, label: "\(todayEventCount) events")
                    glancePill(color: UNConstants.successGreen, label: "\(reminderItems.count) reminders")
                }
            }
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1)
            }

            Spacer(minLength: 0)
        }
    }

    private func glancePill(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(UNConstants.textSecondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(UNConstants.rowSurface)
        )
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            sectionLabel("Reminders")
            if reminderItems.isEmpty {
                glanceRow(icon: "checkmark.circle", tint: UNConstants.successGreen.opacity(0.85),
                          text: "No reminders")
            } else {
                ForEach(reminderItems.prefix(3)) { reminder in
                    HStack(spacing: 8) {
                        Circle()
                            .strokeBorder(UNConstants.textTertiary, lineWidth: 1)
                            .frame(width: 11, height: 11)
                        Text(reminder.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(UNConstants.textSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9).frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
                        .fill(UNConstants.rowSurface))
                }
            }
        }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let groups = dayGroups
            let hasEvents = groups.contains { !$0.events.isEmpty }
            if !hasEvents {
                dayGroupHeader(dayLabel(selectedDate), isToday: cal.isDateInToday(selectedDate))
                glanceRow(
                    icon: "calendar",
                    tint: UNConstants.textTertiary,
                    text: cal.isDateInToday(selectedDate) ? "No upcoming events" : "No events this day"
                )
            } else {
                ForEach(groups, id: \.id) { group in
                    if !group.events.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            dayGroupHeader(group.label, isToday: cal.isDateInToday(group.id))
                            ForEach(group.events, id: \.eventIdentifier) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
            }
        }
    }

    /// What the list shows: the upcoming Today/Tomorrow/… groups when today is selected,
    /// otherwise just the tapped day's events.
    private var dayGroups: [(id: Date, label: String, events: [EKEvent])] {
        if cal.isDateInToday(selectedDate) { return upcomingGroups }
        let day = cal.startOfDay(for: selectedDate)
        let evs = (eventsByDay[day] ?? []).sorted { $0.startDate < $1.startDate }
        return [(id: day, label: dayLabel(day), events: evs)]
    }

    /// Day group header — Today is bolder and larger; Tomorrow and later days are a touch smaller.
    /// Font sizes are multiples of 4.
    private func dayGroupHeader(_ label: String, isToday: Bool) -> some View {
        Text(label)
            .font(.system(size: isToday ? 16 : 12, weight: isToday ? .bold : .semibold))
            .foregroundStyle(isToday ? UNConstants.textPrimary : UNConstants.textSecondary)
    }

    /// Upcoming events grouped by day, labelled Today / Tomorrow / weekday.
    /// Events that began before today but are still ongoing are pulled into the Today group.
    private var upcomingGroups: [(id: Date, label: String, events: [EKEvent])] {
        let today = cal.startOfDay(for: Date())
        let grouped = Dictionary(grouping: ekEvents) { event in
            max(cal.startOfDay(for: event.startDate), today)
        }
        return grouped.keys.sorted().map { day in
            (id: day, label: dayLabel(day), events: grouped[day]!.sorted { $0.startDate < $1.startDate })
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE · d MMM"
        return f.string(from: day)
    }

    private func glanceRow(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundStyle(tint)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(UNConstants.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).frame(height: 32)
        .background(RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
            .fill(UNConstants.rowSurface))
    }

    private func eventRow(_ event: EKEvent) -> some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(nsColor: event.calendar.color ?? .systemBlue))
                .frame(width: 3, height: 22)

            Text(timeString(event))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(UNConstants.textTertiary)
                .frame(width: 42, alignment: .leading)

            Text(event.title ?? "Untitled")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(UNConstants.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9).frame(height: 38)
        .background(RoundedRectangle(cornerRadius: UNConstants.rowCornerRadius, style: .continuous)
            .fill(UNConstants.rowSurface))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(UNConstants.textTertiary)
            .tracking(0.5)
    }

    // MARK: - Permission CTA

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
                Text(permissionMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(UNConstants.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: 330)
            Button { requestCalendarAccess() } label: {
                Text(authStatus == .denied || authStatus == .restricted ? "Open Privacy Settings" : "Grant Access")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UNConstants.accentBlue)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(UNConstants.accentBlue.opacity(0.14)))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 28)
    }

    private var permissionMessage: String {
        switch authStatus {
        case .denied:     return "Calendar access was denied. Enable Utility Notch in System Settings to show local events."
        case .restricted: return "Calendar access is restricted on this Mac. Check Privacy & Security settings."
        default:          return "urNotch reads your local calendars to show upcoming events in the shelf. Nothing leaves this Mac."
        }
    }

    // MARK: - Derived values

    private var monthDays: [MonthDay] {
        guard let monthInterval = cal.dateInterval(of: .month, for: selectedDate) else { return [] }
        let firstWeekday = cal.component(.weekday, from: monthInterval.start)
        let leadingDays = (firstWeekday - cal.firstWeekday + 7) % 7
        guard let firstVisibleDay = cal.date(byAdding: .day, value: -leadingDays, to: monthInterval.start) else { return [] }
        return (0..<42).compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: offset, to: firstVisibleDay) else { return nil }
            let start = cal.startOfDay(for: date)
            let wd = cal.component(.weekday, from: start)
            return MonthDay(
                id: start, date: start, number: cal.component(.day, from: start),
                isInMonth: cal.isDate(start, equalTo: selectedDate, toGranularity: .month),
                isToday: cal.isDateInToday(start),
                isSelected: cal.isDate(start, inSameDayAs: selectedDate),
                isWeekend: wd == 1 || wd == 7
            )
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = cal.shortWeekdaySymbols.map { String($0.prefix(1)).uppercased() }
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var currentMonthYear: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: selectedDate)
    }
    private var monthTitle: String { let f = DateFormatter(); f.dateFormat = "MMMM"; return f.string(from: selectedDate) }
    private var yearTitle: String { let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: selectedDate) }

    private var todayEventCount: Int { (eventsByDay[cal.startOfDay(for: Date())] ?? []).count }

    private var reminderItems: [ReminderRowItem] {
        todayReminders.filter { !$0.isCompleted }
            .map { ReminderRowItem(id: $0.calendarItemIdentifier, title: $0.title ?? "Reminder") }
    }
    private struct ReminderRowItem: Identifiable { let id: String; let title: String }

    private func calendarColors(for evs: [EKEvent]) -> [Color] {
        var seen = Set<String>()
        return evs.compactMap { ev in
            let id = ev.calendar.calendarIdentifier
            guard !seen.contains(id) else { return nil }
            seen.insert(id)
            return Color(nsColor: ev.calendar.color ?? .systemBlue)
        }
    }

    private func dayNumberColor(_ day: MonthDay) -> Color {
        if day.isToday { return .white }
        if !day.isInMonth { return UNConstants.textMuted }
        if day.isWeekend { return UNConstants.textTertiary }
        return UNConstants.textSecondary
    }

    private func timeString(_ event: EKEvent) -> String {
        if event.isAllDay { return "all day" }
        // Started before today but still running → it shows under Today as ongoing.
        if event.startDate < cal.startOfDay(for: Date()) { return "now" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: event.startDate)
    }

    // MARK: - Navigation

    private func shiftMonth(_ delta: Int) {
        guard let d = cal.date(byAdding: .month, value: delta, to: selectedDate) else { return }
        withAnimation(UNMotion.daySelect) { selectedDate = cal.startOfDay(for: d) }
        loadEvents(); loadMonthEvents()
    }

    private func selectDay(_ date: Date) {
        let changedMonth = !cal.isDate(date, equalTo: selectedDate, toGranularity: .month)
        withAnimation(UNMotion.daySelect) { selectedDate = cal.startOfDay(for: date) }
        loadEvents()
        if changedMonth { loadMonthEvents() }
    }

    // MARK: - Data loading

    private func refreshAll() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
        remindersAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
        if isAuthorized {
            loadEvents(); loadMonthEvents(); loadTodayReminders()
        } else {
            removeCalendarActivity()
        }
    }

    /// Upcoming list — anchored to today, spanning the user's lookahead window (1…7 days).
    private func loadEvents() {
        guard isAuthorized else { return }
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: max(lookaheadDays, 1), to: start) ?? start
        let predicate = sharedEventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        ekEvents = sharedEventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        updateCalendarActivity()
    }

    /// Whole visible month → grid indicators, grouped by day, respecting enabled calendars.
    private func loadMonthEvents() {
        guard isAuthorized, let first = monthDays.first?.date, let last = monthDays.last?.date else { return }
        let end = cal.date(byAdding: .day, value: 1, to: last) ?? last

        let raw = UserDefaults.standard.string(forKey: CalKey.enabledIDs) ?? ""
        let enabled = Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        let calendars: [EKCalendar]? = enabled.isEmpty
            ? nil
            : sharedEventStore.calendars(for: .event).filter { enabled.contains($0.calendarIdentifier) }

        let predicate = sharedEventStore.predicateForEvents(withStart: first, end: end, calendars: calendars)
        var grouped: [Date: [EKEvent]] = [:]
        for ev in sharedEventStore.events(matching: predicate) {
            // Tag the event onto every day it spans, not just its start day — otherwise a
            // multi-day (e.g. all-day) event vanishes on any day after the first.
            for day in spannedDays(for: ev, within: first, upTo: end) {
                grouped[day, default: []].append(ev)
            }
        }
        eventsByDay = grouped
    }

    /// Each start-of-day the event covers, clamped to the [lowerBound, upperBound) window.
    /// An event ending exactly at midnight does not count toward that final day.
    private func spannedDays(for event: EKEvent, within lowerBound: Date, upTo upperBound: Date) -> [Date] {
        let lower = cal.startOfDay(for: lowerBound)
        var day = max(cal.startOfDay(for: event.startDate), lower)
        let endExclusive = min(event.endDate, upperBound)
        var days: [Date] = []
        while day < endExclusive, day < upperBound {
            days.append(day)
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        // Zero-duration / instantaneous events still belong to their own day.
        if days.isEmpty {
            let s = cal.startOfDay(for: event.startDate)
            if s >= lower, s < upperBound { days.append(s) }
        }
        return days
    }

    private var isRemindersAuthorized: Bool {
        switch remindersAuthStatus { case .fullAccess, .authorized: return true; default: return false }
    }

    private func loadTodayReminders() {
        remindersAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
        if isRemindersAuthorized { fetchTodayReminders() }
        else if remindersAuthStatus == .notDetermined { requestReminderAccess() }
        else { todayReminders = [] }
    }

    private func requestReminderAccess() {
        Task {
            do {
                if #available(macOS 14.0, *) { _ = try await sharedEventStore.requestFullAccessToReminders() }
                else {
                    _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                        sharedEventStore.requestAccess(to: .reminder) { granted, error in
                            if let error { cont.resume(throwing: error) } else { cont.resume(returning: granted) }
                        }
                    }
                }
            } catch { }
            await MainActor.run {
                remindersAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
                if isRemindersAuthorized { fetchTodayReminders() }
            }
        }
    }

    private func fetchTodayReminders() {
        // Restrict to the user's selected reminder lists (empty = all lists).
        let enabled = Set(enabledReminderIDsRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        let lists: [EKCalendar]? = enabled.isEmpty
            ? nil
            : sharedEventStore.calendars(for: .reminder).filter { enabled.contains($0.calendarIdentifier) }
        let predicate = sharedEventStore.predicateForReminders(in: lists)
        sharedEventStore.fetchReminders(matching: predicate) { reminders in
            let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
            // Actionable reminders: incomplete and either due today, overdue, or with no due date.
            // (The old filter required a due date == today, so undated reminders never showed.)
            let filtered = (reminders ?? [])
                .filter { reminder in
                    guard !reminder.isCompleted else { return false }
                    guard let due = reminderDueDate(reminder) else { return true } // undated → keep
                    return due < startOfTomorrow                                   // today or overdue
                }
                .sorted { a, b in
                    let ad = reminderDueDate(a) ?? .distantFuture
                    let bd = reminderDueDate(b) ?? .distantFuture
                    return ad < bd
                }
            DispatchQueue.main.async { todayReminders = filtered }
        }
    }

    private func reminderDueDate(_ reminder: EKReminder) -> Date? {
        guard var due = reminder.dueDateComponents else { return nil }
        due.calendar = due.calendar ?? cal
        return due.date
    }

    private func requestCalendarAccess() {
        guard !isRequestingAccess else { return }
        if authStatus == .denied || authStatus == .restricted { openCalendarPrivacySettings(); return }
        isRequestingAccess = true
        NSApp.activate(ignoringOtherApps: true)
        Task {
            do {
                if #available(macOS 14.0, *) { _ = try await sharedEventStore.requestFullAccessToEvents() }
                else {
                    _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                        sharedEventStore.requestAccess(to: .event) { granted, error in
                            if let error { cont.resume(throwing: error) } else { cont.resume(returning: granted) }
                        }
                    }
                }
            } catch { }
            await MainActor.run {
                authStatus = EKEventStore.authorizationStatus(for: .event)
                isRequestingAccess = false
                if isAuthorized { loadEvents(); loadMonthEvents(); loadTodayReminders() }
                else { removeCalendarActivity() }
            }
        }
    }

    @MainActor private func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else { return }
        NSWorkspace.shared.open(url)
    }

    @MainActor private func updateCalendarActivity() {
        removeCalendarActivity()
        guard let next = ekEvents.first(where: { $0.startDate >= Date() }) else { return }
        appState.liveActivities.append(
            LiveActivity(
                title: "Next event", subtitle: next.title ?? "Calendar event", icon: "calendar",
                progress: nil, priority: 35, timestamp: next.startDate, destinationModuleID: "calendar"
            )
        )
    }

    @MainActor private func removeCalendarActivity() {
        appState.liveActivities.removeAll { $0.destinationModuleID == "calendar" && $0.icon == "calendar" }
    }
}
