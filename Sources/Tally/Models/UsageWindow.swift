import Foundation

enum UsageWindow: Hashable {
    case rollingHours(Int)  // e.g. Claude 5h session
    case calendarWeek  // resets Monday 00:00 local
    case calendarDay  // resets at next local midnight
    case calendarMonth  // resets on the 1st

    var label: String {
        switch self {
        case .rollingHours(let h): return "\(h)-hour window"
        case .calendarWeek: return "all models"
        case .calendarDay: return "daily"
        case .calendarMonth: return "monthly"
        }
    }

    func windowStart(now: Date = .now, calendar: Calendar = .current) -> Date {
        switch self {
        case .rollingHours(let h):
            return now.addingTimeInterval(-Double(h) * 3600)
        case .calendarWeek:
            var cal = calendar
            cal.firstWeekday = 2  // Monday
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return cal.date(from: comps) ?? now
        case .calendarDay:
            return calendar.startOfDay(for: now)
        case .calendarMonth:
            let comps = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: comps) ?? now
        }
    }

    func resetsAt(now: Date = .now, calendar: Calendar = .current) -> Date {
        switch self {
        case .rollingHours(let h):
            // A rolling window's "next reset" is when the oldest event in the window expires.
            // Without per-event data here we approximate as windowStart + h, callers can override.
            return windowStart(now: now, calendar: calendar).addingTimeInterval(Double(h) * 3600)
        case .calendarWeek:
            return calendar.date(
                byAdding: .weekOfYear, value: 1, to: windowStart(now: now, calendar: calendar)) ?? now
        case .calendarDay:
            return calendar.date(byAdding: .day, value: 1, to: windowStart(now: now, calendar: calendar))
                ?? now
        case .calendarMonth:
            return calendar.date(byAdding: .month, value: 1, to: windowStart(now: now, calendar: calendar))
                ?? now
        }
    }
}
