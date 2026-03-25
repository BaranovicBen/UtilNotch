import SwiftUI

/// Calendar module — full-shell Figma implementation.
/// CSS source: /DesignReference/Css/calendar.css
struct CalendarModuleView: View {
    @Environment(AppState.self) private var appState

    private struct WeekDay {
        let abbrev: String  // "MON", "TUE", etc.
        let day: Int
        let isToday: Bool
    }

    private struct CalEvent: Identifiable {
        let id = UUID()
        let time: String
        let title: String
        let accentColor: Color
    }

    // Dummy week data centered on today (Wed 25 March 2026)
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
        CalEvent(time: "09:00", title: "Team Standup",      accentColor: Color(hex: "42E355")),
        CalEvent(time: "14:00", title: "Design Review",     accentColor: Color(hex: "0A84FF")),
        CalEvent(time: "16:30", title: "1:1 with Manager",  accentColor: Color(hex: "A259FF")),
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
            VStack(alignment: .leading, spacing: 0) {
                // Date Section
                // CSS: Inter 700 48px letter-spacing -2.4px; Inter 500 20px letter-spacing -0.5px rgba(0.5)
                dateSection
                    .padding(.bottom, 16)

                // Week Strip
                // CSS: 7 columns, each padding 8px 0px gap 6px; active bg #0A84FF radius 12px
                weekStrip
                    .padding(.bottom, 16)

                // Upcoming Events
                upcomingSection
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Day number — CSS: Inter 700 48px letter-spacing -2.4px #FFFFFF
            Text("25")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.white)
                .tracking(-2.4)

            // Month + year — CSS: Inter 500 20px letter-spacing -0.5px rgba(255,255,255,0.5)
            Text("March")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(-0.5)
                .padding(.bottom, 6)  // align to baseline of day number

            Spacer()

            // Nav buttons — CSS: 32×32 bg rgba(255,255,255,0.05) radius 8px
            HStack(spacing: 8) {
                navButton(icon: "chevron.left")
                navButton(icon: "chevron.right")
            }
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func navButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.white.opacity(0.7))
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
    }

    // MARK: - Week Strip

    private var weekStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.day) { day in
                weekDayCell(day)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func weekDayCell(_ day: WeekDay) -> some View {
        VStack(spacing: 6) {
            // Day abbrev — CSS: JetBrains Mono 400 10px letter-spacing 1px uppercase
            Text(day.abbrev)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(day.isToday ? Color.white.opacity(0.9) : Color.white.opacity(0.3))
                .kerning(1.0)

            // Day number — CSS: Inter 500 14px; active: Inter 700 14px #FFFFFF
            Text("\(day.day)")
                .font(.system(size: 14, weight: day.isToday ? .bold : .medium))
                .foregroundStyle(day.isToday ? Color.white : Color.white.opacity(0.4))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(
            Group {
                if day.isToday {
                    // CSS: bg #0A84FF radius 12px
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: "0A84FF"))
                }
            }
        )
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header — CSS: JetBrains Mono 400 11px letter-spacing 0.55px uppercase rgba(0.35)
            Text("UPCOMING")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.35))
                .kerning(0.55)

            // Event rows gap: 8px
            VStack(spacing: 8) {
                ForEach(events) { event in
                    eventRow(event)
                }
            }
        }
    }

    // MARK: - Event Row
    // CSS: padding 12px, gap 16px, height 48px, bg rgba(255,255,255,0.05), radius 12px

    @ViewBuilder
    private func eventRow(_ event: CalEvent) -> some View {
        HStack(spacing: 16) {
            // Accent bar — CSS: 4×24px radius 9999px
            RoundedRectangle(cornerRadius: 9999, style: .continuous)
                .fill(event.accentColor)
                .frame(width: 4, height: 24)

            // Time — CSS: JetBrains Mono 400 12px rgba(255,255,255,0.6)
            Text(event.time)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.6))

            // Title — CSS: Inter 500 14px #E5E2E1
            Text(event.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(hex: "E5E2E1"))
                .lineLimit(1)

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}
