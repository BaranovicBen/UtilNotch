import SwiftUI
import EventKit

// MARK: - WeekDay model

struct WeekDay {
    let abbrev: String
    let day: Int
    let date: Date
    let isToday: Bool
    let isSelected: Bool
}

// MARK: - CalendarStore

/// Data layer for the Calendar module.
/// Owns: EKEventStore access, auth state, event fetching, date navigation, settings reads.
/// The CalendarModuleView reads from this store — it never calls EventKit directly.
@Observable
final class CalendarStore {

    // MARK: - State

    var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    var events: [EKEvent] = []
    var selectedDate: Date = Calendar.current.startOfDay(for: .now)
    var isRequesting: Bool = false

    // MARK: - Computed state

    var isAuthorized: Bool { authStatus == .fullAccess }

    var footerLeft: String {
        guard isAuthorized else { return "PERMISSION REQUIRED" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let lookahead = currentLookaheadDays
        if lookahead <= 1 {
            return f.string(from: selectedDate).uppercased()
        }
        let end = Calendar.current.date(byAdding: .day, value: lookahead - 1, to: selectedDate)
        let endStr = end.map { f.string(from: $0) } ?? f.string(from: selectedDate)
        return "\(f.string(from: selectedDate)) – \(endStr)".uppercased()
    }

    var footerRight: String {
        guard isAuthorized else { return "" }
        let count = events.count
        if count == 0 { return "NO EVENTS" }
        return "\(count) EVENT\(count == 1 ? "" : "S")"
    }

    // MARK: - Date helpers (consumed by view)

    var currentDayNumber: String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: selectedDate)
    }

    var currentMonthYear: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedDate)
    }

    var currentWeekDays: [WeekDay] {
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

    // MARK: - Private settings reads (from UserDefaults, written by CalendarSettingsView)

    private var currentLookaheadDays: Int {
        let v = UserDefaults.standard.integer(forKey: CalKey.lookahead)
        return v > 0 ? v : CalLookahead.today.rawValue
    }

    private var enabledCalendarIDs: Set<String> {
        let raw = UserDefaults.standard.string(forKey: CalKey.enabledIDs) ?? ""
        return Set(raw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    // MARK: - EKEventStore change observation

    @ObservationIgnored private var eventStoreToken: NSObjectProtocol?

    init() {
        // Observe live changes from Calendar.app (event added/edited/deleted)
        eventStoreToken = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: sharedEventStore,
            queue: .main
        ) { [weak self] _ in
            self?.loadEvents()
        }
    }

    deinit {
        if let token = eventStoreToken {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Actions

    /// Called from view's .onAppear. Refreshes auth status and loads events if authorized.
    func onAppear() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
        if isAuthorized { loadEvents() }
    }

    /// Fetches events for selectedDate + lookahead window, filtered by enabled calendars.
    /// Safe to call at any time — exits early if not authorized.
    func loadEvents() {
        guard isAuthorized else { return }

        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let end = cal.date(byAdding: .day, value: max(currentLookaheadDays, 1), to: start) ?? start

        let enabledSet = enabledCalendarIDs
        let filteredCalendars: [EKCalendar]? = enabledSet.isEmpty
            ? nil
            : sharedEventStore.calendars(for: .event).filter { enabledSet.contains($0.calendarIdentifier) }

        let predicate = sharedEventStore.predicateForEvents(withStart: start, end: end, calendars: filteredCalendars)
        events = sharedEventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
    }

    /// Requests full calendar access. Updates authStatus and loads events on success.
    func requestAccess() {
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
                    if isAuthorized { loadEvents() }
                }
            } catch {
                await MainActor.run {
                    authStatus = EKEventStore.authorizationStatus(for: .event)
                    isRequesting = false
                }
            }
        }
    }

    /// Moves selectedDate by delta days and reloads events.
    func shiftDay(_ delta: Int) {
        guard let d = Calendar.current.date(byAdding: .day, value: delta, to: selectedDate) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            selectedDate = Calendar.current.startOfDay(for: d)
        }
        loadEvents()
    }

    /// Selects a specific day from the week strip and reloads events.
    func selectDay(_ date: Date) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
            selectedDate = Calendar.current.startOfDay(for: date)
        }
        loadEvents()
    }
}
