import SwiftUI

/// Calendar module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/calendar.css
struct CalendarModuleView: View {
    @Environment(AppState.self) private var appState

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

    private let weekDays: [WeekDay] = [
        WeekDay(abbrev: "MON", day: 23, isToday: false),
        WeekDay(abbrev: "TUE", day: 24, isToday: false),
        WeekDay(abbrev: "WED", day: 25, isToday: true),
        WeekDay(abbrev: "THU", day: 26, isToday: false),
        WeekDay(abbrev: "FRI", day: 27, isToday: false),
        WeekDay(abbrev: "SAT", day: 28, isToday: false),
        WeekDay(abbrev: "SUN", day: 29, isToday: false),
    ]

    private let events: [CalEvent] = [
        CalEvent(time: "09:00", title: "Team Standup",     accentColor: Color(hex: "42E355"), hasVideo: true),
        CalEvent(time: "14:00", title: "Design Review",    accentColor: Color(hex: "0A84FF"), hasVideo: true),
        CalEvent(time: "16:30", title: "1:1 with Manager", accentColor: Color(hex: "A259FF"), hasVideo: false),
    ]

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
            statusDotColor: Color.white.opacity(0.2),
            statusLeft: "MARCH 2026",
            statusRight: "3 UPCOMING",
            actionButton: nil
        ) {
            // STEP 1: Hard cap the content area to 296pt
            // 380 panel − 44 header − 28 footer − 8 top gap − 4 bottom gap = 296
            VStack(alignment: .leading, spacing: 0) {
                dateRow
                weekStrip
                upcomingLabel
                eventRows
            }
            .frame(maxWidth: .infinity, maxHeight: 296, alignment: .top)
            .clipped()
        }
    }

    // MARK: - Date Row
    // Total height: 40pt. Top padding: 12pt.
    // Running total after: 12 + 40 = 52pt

    private var dateRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Date number — 28pt bold
            Text("25")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)

            // Month + year — 13pt regular, bottom-aligned, 8pt left offset
            Text("March 2026")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.leading, 8)
                .padding(.bottom, 3)  // align to bottom of "25"

            Spacer()

            // Prev/next buttons — 24×24, subtle
            HStack(spacing: 8) {
                navButton(icon: "chevron.left")
                navButton(icon: "chevron.right")
            }
        }
        .frame(height: 40)
        .padding(.top, 12)
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
            ForEach(weekDays, id: \.day) { day in
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
                // Fixed 44pt capsule — do not stretch to column width
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
            ForEach(events) { event in
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
                // Color bar — 3×20pt
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(event.accentColor)
                    .frame(width: 3, height: 20)
                    .padding(.leading, 12)

                // Time
                Text(event.time)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.leading, 10)

                // Title
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
}
