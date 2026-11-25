import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .english: return "English"
        }
    }
    var locale: Locale { Locale(identifier: rawValue) }
}

struct SalarySettings: Codable {
    var language: AppLanguage = .simplifiedChinese
    var monthlySalary: Double = 10000
    var yearEndBonus: Double = 0
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
    var percentDecimals: Int = 1
    var secondRateDecimals: Int = 4
    var useChinaHolidayCalendar: Bool = true
    var windowOpacity: Double = 0.96
    var showWeekEarned: Bool = true
    var showMonthEarned: Bool = true
    var showProgress: Bool = true
    var showHourlyRate: Bool = true
    var showDailyRate: Bool = true
    var showSecondRate: Bool = false
    var showAnnualSalary: Bool = false
    var showWorkDuration: Bool = true
    var durationDisplay: DurationDisplay = .hoursMinutesSeconds
    var hourglassAnimationEnabled: Bool = false
    var compactMode: Bool = false
    var useAfterTaxSalary: Bool = false
    var socialInsuranceBase: Double = 10000
    var socialInsuranceRate: Double = 10.5
    var housingFundBase: Double = 10000
    var housingFundRate: Double = 7.0
    var monthlySpecialDeductions: Double = 0
    var numberAnimation: NumberAnimationStyle = .rolling
    var privacyMode: Bool = false
    var afterWorkReminderEnabled: Bool = false
    var afterWorkReminderHour: Int = 18
    var afterWorkReminderMinute: Int = 0
    var wishList: [SalaryWish] = []
    var familyMembers: [FamilySalaryMember] = []
    var windowLocked: Bool = false
    var alwaysOnTop: Bool = false

    private enum CodingKeys: String, CodingKey {
        case monthlySalary, yearEndBonus, workdays, startHour, startMinute, endHour, endMinute
        case lunchStartHour, lunchStartMinute, lunchEndHour, lunchEndMinute
        case mode, theme, decimals, percentDecimals, secondRateDecimals, useChinaHolidayCalendar, windowOpacity
        case showWeekEarned, showMonthEarned, showProgress, showHourlyRate, showDailyRate, showSecondRate, showAnnualSalary, showWorkDuration, durationDisplay, hourglassAnimationEnabled, compactMode
        case useAfterTaxSalary, socialInsuranceBase, socialInsuranceRate, housingFundBase, housingFundRate, monthlySpecialDeductions, numberAnimation
        case privacyMode, afterWorkReminderEnabled, afterWorkReminderHour, afterWorkReminderMinute, wishList
        case familyMembers, windowLocked, alwaysOnTop, language
    }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        language = try values.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .simplifiedChinese
        monthlySalary = try values.decodeIfPresent(Double.self, forKey: .monthlySalary) ?? 10000
        yearEndBonus = try values.decodeIfPresent(Double.self, forKey: .yearEndBonus) ?? 0
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
        percentDecimals = try values.decodeIfPresent(Int.self, forKey: .percentDecimals) ?? 1
        secondRateDecimals = try values.decodeIfPresent(Int.self, forKey: .secondRateDecimals) ?? 4
        useChinaHolidayCalendar = try values.decodeIfPresent(Bool.self, forKey: .useChinaHolidayCalendar) ?? true
        windowOpacity = try values.decodeIfPresent(Double.self, forKey: .windowOpacity) ?? 0.96
        showWeekEarned = try values.decodeIfPresent(Bool.self, forKey: .showWeekEarned) ?? true
        showMonthEarned = try values.decodeIfPresent(Bool.self, forKey: .showMonthEarned) ?? true
        showProgress = try values.decodeIfPresent(Bool.self, forKey: .showProgress) ?? true
        showHourlyRate = try values.decodeIfPresent(Bool.self, forKey: .showHourlyRate) ?? true
        showDailyRate = try values.decodeIfPresent(Bool.self, forKey: .showDailyRate) ?? true
        showSecondRate = try values.decodeIfPresent(Bool.self, forKey: .showSecondRate) ?? false
        showAnnualSalary = try values.decodeIfPresent(Bool.self, forKey: .showAnnualSalary) ?? false
        showWorkDuration = try values.decodeIfPresent(Bool.self, forKey: .showWorkDuration) ?? true
        durationDisplay = try values.decodeIfPresent(DurationDisplay.self, forKey: .durationDisplay) ?? .hoursMinutesSeconds
        hourglassAnimationEnabled = try values.decodeIfPresent(Bool.self, forKey: .hourglassAnimationEnabled) ?? false
        compactMode = try values.decodeIfPresent(Bool.self, forKey: .compactMode) ?? false
        useAfterTaxSalary = try values.decodeIfPresent(Bool.self, forKey: .useAfterTaxSalary) ?? false
        socialInsuranceBase = try values.decodeIfPresent(Double.self, forKey: .socialInsuranceBase) ?? monthlySalary
        socialInsuranceRate = try values.decodeIfPresent(Double.self, forKey: .socialInsuranceRate) ?? 10.5
        housingFundBase = try values.decodeIfPresent(Double.self, forKey: .housingFundBase) ?? monthlySalary
        housingFundRate = try values.decodeIfPresent(Double.self, forKey: .housingFundRate) ?? 7.0
        monthlySpecialDeductions = try values.decodeIfPresent(Double.self, forKey: .monthlySpecialDeductions) ?? 0
        numberAnimation = try values.decodeIfPresent(NumberAnimationStyle.self, forKey: .numberAnimation) ?? .rolling
        privacyMode = try values.decodeIfPresent(Bool.self, forKey: .privacyMode) ?? false
        afterWorkReminderEnabled = try values.decodeIfPresent(Bool.self, forKey: .afterWorkReminderEnabled) ?? false
        afterWorkReminderHour = try values.decodeIfPresent(Int.self, forKey: .afterWorkReminderHour) ?? endHour
        afterWorkReminderMinute = try values.decodeIfPresent(Int.self, forKey: .afterWorkReminderMinute) ?? endMinute
        wishList = try values.decodeIfPresent([SalaryWish].self, forKey: .wishList) ?? []
        familyMembers = try values.decodeIfPresent([FamilySalaryMember].self, forKey: .familyMembers) ?? []
        // Migrate old shared schedules to each member so existing users retain
        // the exact workday times they had before schedules became independent.
        for index in familyMembers.indices {
            if familyMembers[index].needsWorkdaysMigration {
                familyMembers[index].workdays = workdays
                familyMembers[index].needsWorkdaysMigration = false
            }
            if familyMembers[index].needsScheduleMigration {
                familyMembers[index].startHour = startHour
                familyMembers[index].startMinute = startMinute
                familyMembers[index].endHour = endHour
                familyMembers[index].endMinute = endMinute
                familyMembers[index].lunchStartHour = lunchStartHour
                familyMembers[index].lunchStartMinute = lunchStartMinute
                familyMembers[index].lunchEndHour = lunchEndHour
                familyMembers[index].lunchEndMinute = lunchEndMinute
                familyMembers[index].needsScheduleMigration = false
            }
        }
        windowLocked = try values.decodeIfPresent(Bool.self, forKey: .windowLocked) ?? false
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? false
    }
}

struct FamilySalaryMember: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var monthlySalary: Double
    var yearEndBonus: Double = 0
    var workdays: Set<Int> = [2, 3, 4, 5, 6]
    var useAfterTaxSalary: Bool = false
    var socialInsuranceBase: Double = 10000
    var socialInsuranceRate: Double = 10.5
    var housingFundBase: Double = 10000
    var housingFundRate: Double = 7.0
    var monthlySpecialDeductions: Double = 0
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 18
    var endMinute: Int = 0
    var lunchStartHour: Int = 12
    var lunchStartMinute: Int = 0
    var lunchEndHour: Int = 13
    var lunchEndMinute: Int = 0
    fileprivate var needsScheduleMigration: Bool = false
    fileprivate var needsWorkdaysMigration: Bool = false

    private enum CodingKeys: String, CodingKey {
        case id, name, monthlySalary, yearEndBonus, workdays, useAfterTaxSalary, socialInsuranceBase
        case socialInsuranceRate, housingFundBase, housingFundRate, monthlySpecialDeductions
        case startHour, startMinute, endHour, endMinute, lunchStartHour, lunchStartMinute, lunchEndHour, lunchEndMinute
    }

    init(id: UUID = UUID(), name: String, monthlySalary: Double, yearEndBonus: Double = 0, useAfterTaxSalary: Bool = false,
         socialInsuranceBase: Double? = nil, socialInsuranceRate: Double = 10.5,
         housingFundBase: Double? = nil, housingFundRate: Double = 7.0,
         monthlySpecialDeductions: Double = 0) {
        self.id = id
        self.name = name
        self.monthlySalary = monthlySalary
        self.yearEndBonus = yearEndBonus
        self.useAfterTaxSalary = useAfterTaxSalary
        self.socialInsuranceBase = socialInsuranceBase ?? monthlySalary
        self.socialInsuranceRate = socialInsuranceRate
        self.housingFundBase = housingFundBase ?? monthlySalary
        self.housingFundRate = housingFundRate
        self.monthlySpecialDeductions = monthlySpecialDeductions
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try values.decodeIfPresent(String.self, forKey: .name) ?? "家庭成员"
        monthlySalary = try values.decodeIfPresent(Double.self, forKey: .monthlySalary) ?? 10000
        yearEndBonus = try values.decodeIfPresent(Double.self, forKey: .yearEndBonus) ?? 0
        workdays = try values.decodeIfPresent(Set<Int>.self, forKey: .workdays) ?? [2, 3, 4, 5, 6]
        useAfterTaxSalary = try values.decodeIfPresent(Bool.self, forKey: .useAfterTaxSalary) ?? false
        socialInsuranceBase = try values.decodeIfPresent(Double.self, forKey: .socialInsuranceBase) ?? monthlySalary
        socialInsuranceRate = try values.decodeIfPresent(Double.self, forKey: .socialInsuranceRate) ?? 10.5
        housingFundBase = try values.decodeIfPresent(Double.self, forKey: .housingFundBase) ?? monthlySalary
        housingFundRate = try values.decodeIfPresent(Double.self, forKey: .housingFundRate) ?? 7.0
        monthlySpecialDeductions = try values.decodeIfPresent(Double.self, forKey: .monthlySpecialDeductions) ?? 0
        startHour = try values.decodeIfPresent(Int.self, forKey: .startHour) ?? 9
        startMinute = try values.decodeIfPresent(Int.self, forKey: .startMinute) ?? 0
        endHour = try values.decodeIfPresent(Int.self, forKey: .endHour) ?? 18
        endMinute = try values.decodeIfPresent(Int.self, forKey: .endMinute) ?? 0
        lunchStartHour = try values.decodeIfPresent(Int.self, forKey: .lunchStartHour) ?? 12
        lunchStartMinute = try values.decodeIfPresent(Int.self, forKey: .lunchStartMinute) ?? 0
        lunchEndHour = try values.decodeIfPresent(Int.self, forKey: .lunchEndHour) ?? 13
        lunchEndMinute = try values.decodeIfPresent(Int.self, forKey: .lunchEndMinute) ?? 0
        needsScheduleMigration = !values.contains(.startHour) && !values.contains(.endHour)
        needsWorkdaysMigration = !values.contains(.workdays)
    }
}

struct SalaryWish: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var targetAmount: Double
    var savedAmount: Double = 0
}

enum DisplayMode: String, Codable, CaseIterable {
    case money = "金额"
    case percent = "进度"
}


enum DurationDisplay: String, Codable, CaseIterable, Identifiable {
    case hoursMinutesSeconds = "时分秒"
    case hoursMinutes = "时分"
    var id: String { rawValue }
}

enum NumberAnimationStyle: String, Codable, CaseIterable {
    case rolling = "数字滚动"
    case fade = "平滑淡变"
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
    let overtimeSeconds: TimeInterval
    let isOvertime: Bool
    let isPublicHoliday: Bool
    let isMakeupWorkday: Bool
    let dailyRate: Double
    let hourlyRate: Double
    let weekEarned: Double
    let monthEarned: Double
    let tax: Double
    let netMonthlySalary: Double
    let secondRate: Double
    let annualSalary: Double
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
        let monthlyTax = estimatedMonthlyTax(settings: settings)
        let monthlyContributions = estimatedMonthlyContributions(settings: settings)
        let netMonthlySalary = max(0, settings.monthlySalary - monthlyContributions - monthlyTax)
        let calculationSalary = settings.useAfterTaxSalary ? netMonthlySalary : settings.monthlySalary
        let dailyRate = monthlyWorkdays > 0 ? calculationSalary / Double(monthlyWorkdays) : 0
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
        // 加班从个人排班下班时刻开始计算；仅工作日生效，休息日/法定假日不自动计为加班。
        let overtime = dayStatus.isWorkday ? max(0, nowSeconds - end) : 0
        let isOvertime = dayStatus.isWorkday && nowSeconds >= end

        return SalarySnapshot(
            earned: earned,
            progress: progress,
            todayWorkSeconds: total,
            elapsedWorkSeconds: elapsed,
            monthlyWorkdays: monthlyWorkdays,
            isWorkday: dayStatus.isWorkday,
            isWorkingNow: isWorking,
            remainingSeconds: remaining,
            overtimeSeconds: overtime,
            isOvertime: isOvertime,
            isPublicHoliday: dayStatus.isHoliday,
            isMakeupWorkday: dayStatus.isMakeup,
            dailyRate: dailyRate,
            hourlyRate: hourlyRate,
            weekEarned: weekEarned,
            monthEarned: monthEarned,
            tax: monthlyTax,
            netMonthlySalary: netMonthlySalary,
            secondRate: hourlyRate / 3600,
            annualSalary: calculationSalary * 12 + max(0, settings.yearEndBonus)
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

    /// Steady-state monthly IIT estimate using the annual cumulative withholding brackets.
    /// Assumes 12 equal salary months; social insurance and additional deductions are user supplied.
    static func estimatedMonthlyContributions(settings: SalarySettings) -> Double {
        let social = max(0, settings.socialInsuranceBase) * max(0, settings.socialInsuranceRate) / 100
        let housing = max(0, settings.housingFundBase) * max(0, settings.housingFundRate) / 100
        return social + housing
    }

    static func estimatedMonthlyTax(settings: SalarySettings) -> Double {
        let monthlyTaxable = max(0, settings.monthlySalary - 5000
            - estimatedMonthlyContributions(settings: settings)
            - max(0, settings.monthlySpecialDeductions))
        let annualTaxable = monthlyTaxable * 12
        let brackets: [(Double, Double, Double)] = [
            (36000, 0.03, 0), (144000, 0.10, 2520), (300000, 0.20, 16920),
            (420000, 0.25, 31920), (660000, 0.30, 52920),
            (960000, 0.35, 85920), (Double.greatestFiniteMagnitude, 0.45, 181920)
        ]
        let annualTax = brackets.first(where: { annualTaxable <= $0.0 }).map {
            annualTaxable * $1 - $2
        } ?? 0
        return max(0, annualTax / 12)
    }

    private static func seconds(_ hour: Int, _ minute: Int) -> Double {
        Double(hour * 3600 + minute * 60)
    }

    private static func emptySnapshot() -> SalarySnapshot {
        SalarySnapshot(earned: 0, progress: 0, todayWorkSeconds: 0, elapsedWorkSeconds: 0,
                       monthlyWorkdays: 0, isWorkday: false, isWorkingNow: false,
                       remainingSeconds: 0, overtimeSeconds: 0, isOvertime: false, isPublicHoliday: false, isMakeupWorkday: false, dailyRate: 0, hourlyRate: 0, weekEarned: 0, monthEarned: 0, tax: 0, netMonthlySalary: 0, secondRate: 0, annualSalary: 0)
    }
}
