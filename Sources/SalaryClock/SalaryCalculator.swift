import Foundation

struct SalarySettings: Codable {
    var monthlySalary: Double = 10000
    var workdays: Set<Int> = [2, 3, 4, 5, 6] // Calendar weekday: Sun=1 ... Sat=7
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 18
    var endMinute: Int = 0
    var lunchStartHour: Int = 12
    var lunchStartMinute: Int = 0
    var lunchEndHour: Int = 13
    var lunchEndMinute: Int = 0
    var mode: DisplayMode = .money
    var theme: WidgetTheme = .midnight
    var decimals: Int = 4
    var useChinaHolidayCalendar: Bool = true
    var windowOpacity: Double = 0.96
    var showWeekEarned: Bool = true
    var showMonthEarned: Bool = true
    var showProgress: Bool = true
    var showHourlyRate: Bool = true
    var showDailyRate: Bool = true
    var showWorkDuration: Bool = true

    private enum CodingKeys: String, CodingKey {
        case monthlySalary, workdays, startHour, startMinute, endHour, endMinute
        case lunchStartHour, lunchStartMinute, lunchEndHour, lunchEndMinute
        case mode, theme, decimals, useChinaHolidayCalendar, windowOpacity
        case showWeekEarned, showMonthEarned, showProgress, showHourlyRate, showDailyRate, showWorkDuration
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        monthlySalary = try values.decodeIfPresent(Double.self, forKey: .monthlySalary) ?? 10000
        workdays = try values.decodeIfPresent(Set<Int>.self, forKey: .workdays) ?? [2, 3, 4, 5, 6]
        startHour = try values.decodeIfPresent(Int.self, forKey: .startHour) ?? 9
        startMinute = try values.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endHour = try values.decodeIfPresent(Int.self, forKey: .endHour) ?? 18
        endMinute = try values.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
        lunchStartHour = try values.decodeIfPresent(Int.self, forKey: .lunchStartHour) ?? 12
        lunchStartMinute = try values.decodeIfPresent(Int.self, forKey: .lunchStartMinute) ?? 0
        lunchEndHour = try values.decodeIfPresent(Int.self, forKey: .lunchEndHour) ?? 13
        lunchEndMinute = try values.decodeIfPresent(Int.self, forKey: .lunchEndMinute) ?? 0
        mode = try values.decodeIfPresent(DisplayMode.self, forKey: .mode) ?? .money
        theme = try values.decodeIfPresent(WidgetTheme.self, forKey: .theme) ?? .midnight
        decimals = try values.decodeIfPresent(Int.self, forKey: .decimals) ?? 4
        useChinaHolidayCalendar = try values.decodeIfPresent(Bool.self, forKey: .useChinaHolidayCalendar) ?? true
        windowOpacity = try values.decodeIfPresent(Double.self, forKey: .windowOpacity) ?? 0.96
        showWeekEarned = try values.decodeIfPresent(Bool.self, forKey: .showWeekEarned) ?? true
        showMonthEarned = try values.decodeIfPresent(Bool.self, forKey: .showMonthEarned) ?? true
        showProgress = try values.decodeIfPresent(Bool.self, forKey: .showProgress) ?? true
        showHourlyRate = try values.decodeIfPresent(Bool.self, forKey: .showHourlyRate) ?? true
        showDailyRate = try values.decodeIfPresent(Bool.self, forKey: .showDailyRate) ?? true
        showWorkDuration = try values.decodeIfPresent(Bool.self, forKey: .showWorkDuration) ?? true
    }
}

enum DisplayMode: String, Codable, CaseIterable {
    case money = "金额"
    case percent = "进度"
}

enum WidgetTheme: String, Codable, CaseIterable {
    case midnight = "深空"
    case paper = "纸感"
    case neon = "霓虹"
    case ocean = "海盐蓝"
    case sunset = "日落橙"
    case graphite = "石墨灰"
}

struct SalarySnapshot {
    let earned: Double
    let progress: Double
    let todayWorkSeconds: TimeInterval
    let elapsedWorkSeconds: TimeInterval
    let monthlyWorkdays: Int
    let isWorkday: Bool
    let isWorkingNow: Bool
    let remainingSeconds: TimeInterval
    let isPublicHoliday: Bool
    let isMakeupWorkday: Bool
    let dailyRate: Double
    let hourlyRate: Double
    let weekEarned: Double
    let monthEarned: Double
}

enum ChinaWorkCalendar {
    private static let holidayRanges: [Int: [(Int, Int)]] = [
        2026: [
            (20260101, 20260103), (20260215, 20260223), (20260404, 20260406),
            (20260501, 20260505), (20260619, 20260621), (20260925, 20260927),
            (20261001, 20261007)
        ],
        2027: [
            (20270101, 20270103), (20270205, 20270213), (20270403, 20270405),
            (20270501, 20270505), (20270609, 20270609), (20270915, 20270915),
            (20271001, 20271007)
        ]
    ]

    private static let makeupWorkdays: [Int: Set<Int>] = [
        2026: [20260104, 20260214, 20260228, 20260509, 20260920, 20261010],
        2027: [20270131, 20270214, 20270508, 20270926, 20271009]
    ]

    static func dateKey(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }

    static func classification(for date: Date, settings: SalarySettings, calendar: Calendar) -> (isWorkday: Bool, isHoliday: Bool, isMakeup: Bool) {
        let key = dateKey(date, calendar: calendar)
        let year = key / 10000

        if settings.useChinaHolidayCalendar {
            if makeupWorkdays[year]?.contains(key) == true {
                return (true, false, true)
            }
            if holidayRanges[year]?.contains(where: { key >= $0.0 && key <= $0.1 }) == true {
                return (false, true, false)
            }
        }

        let weekday = calendar.component(.weekday, from: date)
        return (settings.workdays.contains(weekday), false, false)
    }
}

enum SalaryCalculator {
    static func snapshot(settings: SalarySettings, now: Date = Date(), calendar: Calendar = .current) -> SalarySnapshot {
        let components = calendar.dateComponents([.year, .month], from: now)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: monthStart) else {
            return emptySnapshot()
        }

        var monthlyWorkdays = 0
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { continue }
            if ChinaWorkCalendar.classification(for: date, settings: settings, calendar: calendar).isWorkday {
                monthlyWorkdays += 1
            }
        }

        let dayStatus = ChinaWorkCalendar.classification(for: now, settings: settings, calendar: calendar)
        let start = seconds(settings.startHour, settings.startMinute)
        let end = seconds(settings.endHour, settings.endMinute)
        let lunchStart = seconds(settings.lunchStartHour, settings.lunchStartMinute)
        let lunchEnd = seconds(settings.lunchEndHour, settings.lunchEndMinute)
        let nowSeconds = seconds(calendar.component(.hour, from: now), calendar.component(.minute, from: now))
            + Double(calendar.component(.second, from: now))
            + Double(calendar.component(.nanosecond, from: now)) / 1_000_000_000

        let shiftDuration = max(0, end - start)
        let validLunch = lunchEnd > lunchStart
        let lunchOverlap = validLunch
            ? max(0, min(end, lunchEnd) - max(start, lunchStart))
            : 0
        let total = max(0, shiftDuration - lunchOverlap)

        let elapsedRaw = min(shiftDuration, max(0, nowSeconds - start))
        let elapsedLunch = validLunch
            ? max(0, min(nowSeconds, lunchEnd) - max(start, lunchStart))
            : 0
        let elapsed = dayStatus.isWorkday ? min(total, max(0, elapsedRaw - elapsedLunch)) : 0
        let progress = total > 0 && dayStatus.isWorkday ? min(1, max(0, elapsed / total)) : 0
        let dailyRate = monthlyWorkdays > 0 ? settings.monthlySalary / Double(monthlyWorkdays) : 0
        let earned = dailyRate * progress
        let hourlyRate = total > 0 ? dailyRate / total * 3600 : 0
        let todayStart = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: todayStart)
        let daysSinceMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: todayStart) ?? todayStart
        let weekEarned = accumulatedEarned(from: weekStart, through: todayStart, now: now, dailyRate: dailyRate, settings: settings, calendar: calendar)
        let monthEarned = accumulatedEarned(from: monthStart, through: todayStart, now: now, dailyRate: dailyRate, settings: settings, calendar: calendar)

        let isLunch = validLunch && nowSeconds >= lunchStart && nowSeconds < lunchEnd
        let isWorking = dayStatus.isWorkday && nowSeconds >= start && nowSeconds < end && !isLunch
        let remaining = dayStatus.isWorkday ? max(0, total - elapsed) : 0

        return SalarySnapshot(
            earned: earned,
            progress: progress,
            todayWorkSeconds: total,
            elapsedWorkSeconds: elapsed,
            monthlyWorkdays: monthlyWorkdays,
            isWorkday: dayStatus.isWorkday,
            isWorkingNow: isWorking,
            remainingSeconds: remaining,
            isPublicHoliday: dayStatus.isHoliday,
            isMakeupWorkday: dayStatus.isMakeup,
            dailyRate: dailyRate,
            hourlyRate: hourlyRate,
            weekEarned: weekEarned,
            monthEarned: monthEarned
        )
    }

    private static func accumulatedEarned(from startDate: Date, through endDate: Date, now: Date, dailyRate: Double, settings: SalarySettings, calendar: Calendar) -> Double {
        guard dailyRate > 0 else { return 0 }
        var totalEarned = 0.0
        var date = calendar.startOfDay(for: startDate)
        let lastDate = calendar.startOfDay(for: endDate)
        while date <= lastDate {
            let status = ChinaWorkCalendar.classification(for: date, settings: settings, calendar: calendar)
            if status.isWorkday {
                if date < lastDate {
                    totalEarned += dailyRate
                } else {
                    let start = seconds(settings.startHour, settings.startMinute)
                    let end = seconds(settings.endHour, settings.endMinute)
                    let lunchStart = seconds(settings.lunchStartHour, settings.lunchStartMinute)
                    let lunchEnd = seconds(settings.lunchEndHour, settings.lunchEndMinute)
                    let shift = max(0, end - start)
                    let lunch = lunchEnd > lunchStart ? max(0, min(end, lunchEnd) - max(start, lunchStart)) : 0
                    let effective = max(0, shift - lunch)
                    let nowSeconds = seconds(calendar.component(.hour, from: now), calendar.component(.minute, from: now))
                        + Double(calendar.component(.second, from: now))
                        + Double(calendar.component(.nanosecond, from: now)) / 1_000_000_000
                    let elapsedRaw = min(shift, max(0, nowSeconds - start))
                    let elapsedLunch = lunchEnd > lunchStart ? max(0, min(nowSeconds, lunchEnd) - max(start, lunchStart)) : 0
                    let progress = effective > 0 ? min(1, max(0, elapsedRaw - elapsedLunch) / effective) : 0
                    totalEarned += dailyRate * progress
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return totalEarned
    }

    private static func seconds(_ hour: Int, _ minute: Int) -> Double {
        Double(hour * 3600 + minute * 60)
    }

    private static func emptySnapshot() -> SalarySnapshot {
        SalarySnapshot(earned: 0, progress: 0, todayWorkSeconds: 0, elapsedWorkSeconds: 0,
                       monthlyWorkdays: 0, isWorkday: false, isWorkingNow: false,
                       remainingSeconds: 0, isPublicHoliday: false, isMakeupWorkday: false, dailyRate: 0, hourlyRate: 0, weekEarned: 0, monthEarned: 0)
    }
}
