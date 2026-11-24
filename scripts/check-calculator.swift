import Foundation

@main
struct CalculatorChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
        }

        var settings = SalarySettings()
        settings.monthlySalary = 22000
        settings.workdays = [2, 3, 4, 5, 6]
        settings.startHour = 9
        settings.endHour = 18
        settings.lunchStartHour = 12
        settings.lunchEndHour = 13

        let morning = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 10), calendar: calendar)
        let lunch = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 12, 30), calendar: calendar)
        let afterLunch = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 13), calendar: calendar)
        let finish = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 18), calendar: calendar)
        let sunday = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 29, 11), calendar: calendar)

        precondition(abs(morning.progress - 1.0 / 8.0) < 0.0001, "上午累计进度错误")
        precondition(abs(lunch.progress - 3.0 / 8.0) < 0.0001, "午休期间不应累计")
        precondition(abs(afterLunch.progress - lunch.progress) < 0.0001, "午休结束瞬间金额不应跳变")
        precondition(abs(lunch.remainingSeconds - 5 * 3600) < 1, "午休期间剩余工作时间错误")
        precondition(abs(finish.progress - 1.0) < 0.0001, "下班时进度应为 100%")
        precondition(abs(finish.earned - 22000.0 / Double(finish.monthlyWorkdays)) < 0.01, "日薪金额计算错误")
        precondition(!sunday.isWorkday && sunday.earned == 0, "普通周日不应累计收入")
        precondition(abs(morning.dailyRate - 22000.0 / Double(morning.monthlyWorkdays)) < 0.01, "日薪字段计算错误")
        precondition(abs(morning.hourlyRate - morning.dailyRate / 8.0) < 0.01, "时薪字段计算错误")
        precondition(abs(morning.weekEarned - morning.dailyRate * 1.125) < 0.01, "本周累计收入应包含前一完整工作日和今日实时进度")
        precondition(abs(morning.monthEarned - morning.dailyRate * 16.125) < 0.01, "本月累计收入计算错误")

        let makeup2026 = SalaryCalculator.snapshot(settings: settings, now: date(2026, 9, 20, 10), calendar: calendar)
        let holiday2026 = SalaryCalculator.snapshot(settings: settings, now: date(2026, 10, 1, 10), calendar: calendar)
        let makeup2027 = SalaryCalculator.snapshot(settings: settings, now: date(2027, 1, 31, 10), calendar: calendar)
        let holiday2027 = SalaryCalculator.snapshot(settings: settings, now: date(2027, 2, 5, 10), calendar: calendar)

        precondition(makeup2026.isWorkday && makeup2026.isMakeupWorkday, "2026-09-20 应为调休补班日")
        precondition(!holiday2026.isWorkday && holiday2026.isPublicHoliday, "2026-10-01 应为法定假期")
        precondition(makeup2027.isWorkday && makeup2027.isMakeupWorkday, "2027-01-31 应为调休补班日")
        precondition(!holiday2027.isWorkday && holiday2027.isPublicHoliday, "2027-02-05 应为法定假期")

        let october2026 = SalaryCalculator.snapshot(settings: settings, now: date(2026, 10, 15), calendar: calendar)
        let february2027 = SalaryCalculator.snapshot(settings: settings, now: date(2027, 2, 15), calendar: calendar)
        let may2027 = SalaryCalculator.snapshot(settings: settings, now: date(2027, 5, 15), calendar: calendar)
        precondition(october2026.monthlyWorkdays == 18, "2026 年 10 月工作日统计应包含国庆假期和补班")
        precondition(february2027.monthlyWorkdays == 15, "2027 年 2 月工作日统计应包含春节假期和补班")
        precondition(may2027.monthlyWorkdays == 19, "2027 年 5 月工作日统计应包含劳动节假期和补班")

        var calendarDisabled = settings
        calendarDisabled.useChinaHolidayCalendar = false
        let regularWeekday = SalaryCalculator.snapshot(settings: calendarDisabled, now: date(2026, 10, 1, 10), calendar: calendar)
        let regularSunday = SalaryCalculator.snapshot(settings: calendarDisabled, now: date(2026, 9, 20, 10), calendar: calendar)
        precondition(regularWeekday.isWorkday && !regularWeekday.isPublicHoliday, "关闭节假日日历后应回到每周规则")
        precondition(!regularSunday.isWorkday && !regularSunday.isMakeupWorkday, "关闭节假日日历后周日不应自动补班")

        let legacyJSON = """
        {"monthlySalary":12000,"workdays":[2,3,4,5,6],"startHour":9,"startMinute":0,"endHour":18,"endMinute":0,"lunchStartHour":12,"lunchStartMinute":0,"lunchEndHour":13,"lunchEndMinute":0,"mode":"金额","theme":"深空","decimals":4}
        """.data(using: .utf8)!
        let migrated = try! JSONDecoder().decode(SalarySettings.self, from: legacyJSON)
        precondition(migrated.monthlySalary == 12000 && migrated.useChinaHolidayCalendar && migrated.windowOpacity == 0.96 && migrated.showWeekEarned && migrated.showMonthEarned && migrated.showProgress && migrated.showHourlyRate && migrated.showDailyRate && migrated.showWorkDuration,
                     "旧版本配置向前兼容失败")

        print("通过：21 项检查（工作时段、午休、日薪时薪、本周与本月累计、周末、2026/2027 节假日及补班、月度工作日统计、日历开关、旧配置迁移）")
    }
}
