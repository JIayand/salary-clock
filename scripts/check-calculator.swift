import Foundation

@main
struct CalculatorChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 10, _ minute: Int = 0, _ second: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
        }

        var settings = SalarySettings()
        precondition(!settings.lunchBreakEnabled, "新配置默认不启用午休")
        let newFamilyMember = FamilySalaryMember(name: "新成员", monthlySalary: 12000)
        precondition(!newFamilyMember.lunchBreakEnabled, "新建家庭成员默认不启用午休")
        precondition(NumericFormatting.number(1234567.8, fractionDigits: 2) == "1,234,567.80"
                     && NumericFormatting.integer(-1234567) == "-1,234,567"
                     && NumericFormatting.currency(12345.6) == "¥ 12,345.60",
                     "金额、百分比和整数的千位分隔格式化失败")
        settings.monthlySalary = 22000
        settings.workdays = [2, 3, 4, 5, 6]
        settings.startHour = 9
        settings.endHour = 18
        settings.lunchStartHour = 12
        settings.lunchEndHour = 13
        settings.lunchBreakEnabled = true

        let morning = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 10), calendar: calendar)
        let lunch = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 12, 30), calendar: calendar)
        let afterLunch = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 13), calendar: calendar)
        let finish = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 18), calendar: calendar)
        let sunday = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 29, 11), calendar: calendar)

        precondition(abs(morning.progress - 1.0 / 8.0) < 0.0001, "上午累计进度错误")
        precondition(abs(lunch.progress - 3.0 / 8.0) < 0.0001, "午休期间不应累计")
        precondition(abs(afterLunch.progress - lunch.progress) < 0.0001, "午休结束瞬间金额不应跳变")
        precondition(abs(lunch.remainingSeconds - 5 * 3600) < 1, "午休期间剩余工作时间错误")
        var noLunchSettings = settings
        noLunchSettings.lunchBreakEnabled = false
        let noLunchAt1230 = SalaryCalculator.snapshot(settings: noLunchSettings, now: date(2026, 11, 24, 12, 30), calendar: calendar)
        let noLunchFinish = SalaryCalculator.snapshot(settings: noLunchSettings, now: date(2026, 11, 24, 18), calendar: calendar)
        precondition(abs(noLunchAt1230.progress - 3.5 / 9.0) < 0.0001
                     && abs(noLunchFinish.todayWorkSeconds - 9 * 3600) < 1,
                     "关闭午休后应按完整上下班时段计算，不扣除午休")
        precondition(abs(finish.progress - 1.0) < 0.0001, "下班时进度应为 100%")
        let justAfterFinish = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 18, 0, 5), calendar: calendar)
        let oneHourOvertime = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 24, 19, 0), calendar: calendar)
        precondition(!finish.isOvertime && finish.overtimeSeconds == 0, "到达下班时刻不应自动进入加班状态")
        precondition(!justAfterFinish.isOvertime && justAfterFinish.overtimeSeconds == 0, "用户未选择继续加班时，不应自动累计加班时间")
        precondition(!oneHourOvertime.isOvertime && oneHourOvertime.overtimeSeconds == 0, "计划下班后不应默认持续计时")
        precondition(oneHourOvertime.progress == 1 && abs(oneHourOvertime.earned - finish.earned) < 0.001, "加班不应继续增加正常工时进度或日薪金额")
        let sundayAfterHours = SalaryCalculator.snapshot(settings: settings, now: date(2026, 11, 29, 22), calendar: calendar)
        precondition(!sundayAfterHours.isOvertime && sundayAfterHours.overtimeSeconds == 0, "非工作日不应自动累计加班")
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
        precondition(migrated.monthlySalary == 12000 && migrated.useChinaHolidayCalendar && migrated.windowOpacity == 0.96 && migrated.showWeekEarned && migrated.showMonthEarned && migrated.showProgress && migrated.showHourlyRate && migrated.showDailyRate && migrated.showWorkDuration && !migrated.compactMode,
                     "旧版本配置向前兼容失败")
        precondition(migrated.familyMembers.isEmpty && !migrated.windowLocked,
                     "旧配置的家庭成员和窗口锁定默认值迁移失败")
        precondition(migrated.language == .simplifiedChinese, "旧配置应默认使用简体中文")
        precondition(migrated.lunchBreakEnabled, "旧配置升级后应保留原有午休扣除行为")
        precondition(!migrated.effectiveWorkTrackingEnabled, "旧版本升级后，有效工时统计必须默认关闭")
        precondition(migrated.estimatedRestroomBreakMinutes == 30
                     && migrated.estimatedPhoneBreakMinutes == 20
                     && migrated.estimatedShortBreakMinutes == 10
                     && migrated.estimatedMealBreakMinutes == 0
                     && migrated.estimatedOtherBreakMinutes == 0,
                     "旧版本升级后的每日休息估算默认值迁移失败")
        precondition(migrated.deductRestroomBreaks && migrated.deductPhoneBreaks
                     && migrated.deductShortBreaks && !migrated.deductMealBreaks && migrated.deductOtherBreaks,
                     "休息类型的默认扣除规则迁移失败")
        var trackingSettings = migrated
        trackingSettings.effectiveWorkTrackingEnabled = true
        trackingSettings.deductMealBreaks = true
        let trackingRoundTrip = try! JSONDecoder().decode(SalarySettings.self, from: JSONEncoder().encode(trackingSettings))
        precondition(trackingRoundTrip.effectiveWorkTrackingEnabled && trackingRoundTrip.deductMealBreaks,
                     "有效工时功能开关和分类扣除规则持久化失败")
        trackingSettings.effectiveWorkTrackingStartedAt = date(2026, 11, 24, 9)
        trackingSettings.estimatedRestroomBreakMinutes = 35
        trackingSettings.estimatedPhoneBreakMinutes = 15
        let estimateRoundTrip = try! JSONDecoder().decode(SalarySettings.self, from: JSONEncoder().encode(trackingSettings))
        precondition(estimateRoundTrip.effectiveWorkTrackingStartedAt == date(2026, 11, 24, 9)
                     && estimateRoundTrip.estimatedRestroomBreakMinutes == 35
                     && estimateRoundTrip.estimatedPhoneBreakMinutes == 15
                     && estimateRoundTrip.estimatedShortBreakMinutes == 10,
                     "每日休息估算配置持久化失败")
        let breakStart = date(2026, 11, 24, 10, 15)
        let breakRecord = WorkBreakRecord(id: UUID(), type: .restroom, startTime: breakStart,
                                          endTime: date(2026, 11, 24, 10, 25), deductFromWork: true)
        let savedBreak = try! JSONDecoder().decode(WorkBreakRecord.self, from: JSONEncoder().encode(breakRecord))
        let overtimeSession = OvertimeSession(id: UUID(), startTime: date(2026, 11, 24, 18, 15), endTime: date(2026, 11, 24, 20, 0))
        let restoredOvertime = try! JSONDecoder().decode(OvertimeSession.self, from: JSONEncoder().encode(overtimeSession))
        precondition(restoredOvertime.startTime == overtimeSession.startTime
                     && restoredOvertime.endTime == overtimeSession.endTime
                     && abs(restoredOvertime.duration - 6300) < 0.01,
                     "加班起止时间记录持久化失败")
        precondition(savedBreak.type == .restroom && savedBreak.startTime == breakRecord.startTime
                     && savedBreak.endTime == breakRecord.endTime && savedBreak.deductFromWork,
                     "休息记录编码 / 解码失败")
        let lunchBreak = WorkBreakRecord(id: UUID(), type: .meal,
                                         startTime: date(2026, 11, 24, 12, 15),
                                         endTime: date(2026, 11, 24, 12, 45), deductFromWork: true)
        let afterWorkBreak = WorkBreakRecord(id: UUID(), type: .phone,
                                             startTime: date(2026, 11, 24, 18, 15),
                                             endTime: date(2026, 11, 24, 18, 30), deductFromWork: true)
        let deductedBreakSeconds = WorkBreakCalculator.deductedWorkSeconds(
            records: [breakRecord, lunchBreak, afterWorkBreak], activeRecord: nil,
            now: date(2026, 11, 24, 18, 30), on: date(2026, 11, 24),
            settings: migrated, calendar: calendar
        )
        precondition(abs(deductedBreakSeconds - 600) < 0.01,
                     "有效工时扣除应只计算工作时段内的休息，且不得重复扣除午休或下班后的时间")
        var workdayWithoutLunch = migrated
        workdayWithoutLunch.lunchBreakEnabled = false
        let lunchCountsAsWorkBreakWhenNoLunchSchedule = WorkBreakCalculator.deductedWorkSeconds(
            records: [lunchBreak], activeRecord: nil,
            now: date(2026, 11, 24, 18), on: date(2026, 11, 24),
            settings: workdayWithoutLunch, calendar: calendar
        )
        precondition(abs(lunchCountsAsWorkBreakWhenNoLunchSchedule - 1800) < 0.01,
                     "未启用午休时，中午时段属于工作时间，期间记录的休息应正常计入")
        var estimateSettings = migrated
        estimateSettings.effectiveWorkTrackingEnabled = true
        estimateSettings.effectiveWorkTrackingStartedAt = date(2026, 11, 24)
        estimateSettings.estimatedRestroomBreakMinutes = 30
        estimateSettings.estimatedPhoneBreakMinutes = 20
        estimateSettings.estimatedShortBreakMinutes = 10
        estimateSettings.estimatedMealBreakMinutes = 45
        estimateSettings.deductMealBreaks = false
        let estimatedDeduction = WorkBreakCalculator.deductedWorkSeconds(
            records: [breakRecord], activeRecord: nil,
            now: date(2026, 11, 24, 18, 0), on: date(2026, 11, 24),
            settings: estimateSettings, calendar: calendar
        )
        precondition(abs(estimatedDeduction - 3600) < 0.01,
                     "每日估算应按类型合并，且不得与同类型实际记录重复相加或扣除未启用的吃饭估算")
        let longerActualBreak = WorkBreakRecord(id: UUID(), type: .restroom,
                                                startTime: date(2026, 11, 24, 10),
                                                endTime: date(2026, 11, 24, 10, 45), deductFromWork: true)
        let actualExceedsEstimate = WorkBreakCalculator.deductedWorkSeconds(
            records: [longerActualBreak], activeRecord: nil,
            now: date(2026, 11, 24, 18), on: date(2026, 11, 24),
            settings: estimateSettings, calendar: calendar
        )
        precondition(abs(actualExceedsEstimate - 4500) < 0.01,
                     "实际休息超过每日估算时，应按实际时长扣除")
        var displayEstimateSettings = estimateSettings
        displayEstimateSettings.estimatedRestroomBreakMinutes = 60
        displayEstimateSettings.estimatedPhoneBreakMinutes = 0
        displayEstimateSettings.estimatedShortBreakMinutes = 0
        displayEstimateSettings.estimatedMealBreakMinutes = 0
        displayEstimateSettings.estimatedOtherBreakMinutes = 0
        let halfHourRestroomRecord = WorkBreakRecord(
            id: UUID(), type: .restroom,
            startTime: date(2026, 11, 24, 10),
            endTime: date(2026, 11, 24, 10, 30),
            deductFromWork: true
        )
        let estimatedOrActual = WorkBreakCalculator.combinedBreakSeconds(
            records: [halfHourRestroomRecord], activeRecord: nil,
            now: date(2026, 11, 24, 18), on: date(2026, 11, 24),
            settings: displayEstimateSettings, calendar: calendar
        )
        precondition(abs(estimatedOrActual - 3600) < 0.01,
                     "上厕所每日估算 60 分钟、实际记录 30 分钟时，今日预估休息应为 60 分钟而非 90 分钟")
        let longerRestroomRecord = WorkBreakRecord(
            id: UUID(), type: .restroom,
            startTime: date(2026, 11, 24, 10),
            endTime: date(2026, 11, 24, 11, 30),
            deductFromWork: true
        )
        let actualOverridesEstimate = WorkBreakCalculator.combinedBreakSeconds(
            records: [longerRestroomRecord], activeRecord: nil,
            now: date(2026, 11, 24, 18), on: date(2026, 11, 24),
            settings: displayEstimateSettings, calendar: calendar
        )
        precondition(abs(actualOverridesEstimate - 5400) < 0.01,
                     "实际记录超过每日估算时，今日预估休息应按实际记录时长计入")
        let partialDayEstimate = WorkBreakCalculator.deductedWorkSeconds(
            records: [], activeRecord: nil,
            now: date(2026, 11, 24, 10), on: date(2026, 11, 24),
            settings: estimateSettings, calendar: calendar
        )
        precondition(abs(partialDayEstimate - 450) < 0.01,
                     "当天估算应随已经过的计划工作时间逐步累计")
        let weekendEstimate = WorkBreakCalculator.deductedWorkSeconds(
            records: [], activeRecord: nil,
            now: date(2026, 11, 29, 18), on: date(2026, 11, 29),
            settings: estimateSettings, calendar: calendar
        )
        precondition(weekendEstimate == 0,
                     "非工作日不应应用每日固定休息估算")
        var trackingNotStartedYet = estimateSettings
        trackingNotStartedYet.effectiveWorkTrackingStartedAt = date(2026, 11, 25)
        let beforeTrackingStart = WorkBreakCalculator.deductedWorkSeconds(
            records: [], activeRecord: nil,
            now: date(2026, 11, 24, 18), on: date(2026, 11, 24),
            settings: trackingNotStartedYet, calendar: calendar
        )
        precondition(beforeTrackingStart == 0,
                     "启用每日估算前的历史日期不应被追溯扣除")
        let legacyFamilyJSON = #"{"monthlySalary":15000,"startHour":8,"startMinute":30,"endHour":17,"endMinute":30,"lunchStartHour":12,"lunchEndHour":13,"familyMembers":[{"name":"旧家庭成员","monthlySalary":9000}]}"#.data(using: .utf8)!
        let migratedFamily = try! JSONDecoder().decode(SalarySettings.self, from: legacyFamilyJSON)
        let migratedMember = migratedFamily.familyMembers[0]
        precondition(migratedMember.workdays == migratedFamily.workdays,
                     "旧家庭成员应继承升级前的共享每周工作制度")
        precondition(migratedMember.startHour == 8 && migratedMember.startMinute == 30
                     && migratedMember.endHour == 17 && migratedMember.endMinute == 30
                     && migratedMember.lunchStartHour == 12 && migratedMember.lunchEndHour == 13
                     && migratedMember.lunchBreakEnabled,
                     "旧版本家庭成员应继承升级前的共享工作时间")
        let legacyPersonalScheduleJSON = #"{"monthlySalary":15000,"workdays":[2,3,4,5,6],"startHour":8,"endHour":17,"familyMembers":[{"name":"已有独立时间的成员","monthlySalary":9000,"startHour":10,"startMinute":30,"endHour":19,"endMinute":30,"lunchStartHour":13,"lunchEndHour":14}]}"#.data(using: .utf8)!
        let migratedPersonalSchedule = try! JSONDecoder().decode(SalarySettings.self, from: legacyPersonalScheduleJSON)
        let preservedMember = migratedPersonalSchedule.familyMembers[0]
        precondition(preservedMember.workdays == migratedPersonalSchedule.workdays
                     && preservedMember.startHour == 10 && preservedMember.startMinute == 30
                     && preservedMember.endHour == 19 && preservedMember.endMinute == 30
                     && preservedMember.lunchStartHour == 13 && preservedMember.lunchEndHour == 14,
                     "新增每周工作制度字段时，不得覆盖成员已有的独立上下班时间")
        for language in AppLanguage.allCases {
            var languageSettings = migrated
            languageSettings.language = language
            let encoded = try! JSONEncoder().encode(languageSettings)
            let decoded = try! JSONDecoder().decode(SalarySettings.self, from: encoded)
            precondition(decoded.language == language, "语言设置持久化失败：\\(language.rawValue)")
        }
        var compactSettings = migrated
        compactSettings.compactMode = true
        let compactData = try! JSONEncoder().encode(compactSettings)
        let compactReloaded = try! JSONDecoder().decode(SalarySettings.self, from: compactData)
        precondition(compactReloaded.compactMode, "紧凑模式配置持久化失败")
        compactSettings.percentDecimals = 3
        let percentData = try! JSONEncoder().encode(compactSettings)
        let percentReloaded = try! JSONDecoder().decode(SalarySettings.self, from: percentData)
        precondition(percentReloaded.percentDecimals == 3, "百分比小数位配置持久化失败")
        precondition(migrated.percentDecimals == 1, "旧配置百分比小数位默认值迁移失败")
        var taxSettings = SalarySettings()
        taxSettings.monthlySalary = 10000
        taxSettings.socialInsuranceBase = 10000
        taxSettings.socialInsuranceRate = 10.5
        taxSettings.housingFundBase = 10000
        taxSettings.housingFundRate = 7
        let expectedContributions = 1750.0
        precondition(abs(SalaryCalculator.estimatedMonthlyContributions(settings: taxSettings) - expectedContributions) < 0.01,
                         "社保和公积金比例计算错误")
        let expectedTax = (39000.0 * 0.10 - 2520) / 12
        precondition(abs(SalaryCalculator.estimatedMonthlyTax(settings: taxSettings) - expectedTax) < 0.01,
                         "月度个税估算错误")
        taxSettings.monthlySpecialDeductions = 2000
        let reducedTax = SalaryCalculator.estimatedMonthlyTax(settings: taxSettings)
        precondition(reducedTax < expectedTax, "社保和专项附加扣除应降低预计个税")
        taxSettings.useAfterTaxSalary = true
        let afterTaxSnapshot = SalaryCalculator.snapshot(settings: taxSettings, now: date(2026, 11, 24, 10), calendar: calendar)
        precondition(afterTaxSnapshot.netMonthlySalary < taxSettings.monthlySalary, "税后工资应低于税前工资")
        precondition(abs(afterTaxSnapshot.dailyRate - afterTaxSnapshot.netMonthlySalary / Double(afterTaxSnapshot.monthlyWorkdays)) < 0.01,
                         "启用税后工资后日薪应按税后月薪计算")
        var featureSettings = migrated
        featureSettings.privacyMode = true
        featureSettings.afterWorkReminderEnabled = true
        featureSettings.afterWorkReminderHour = 18
        featureSettings.afterWorkReminderMinute = 30
        featureSettings.wishList = [SalaryWish(name: "旅行", targetAmount: 20000, savedAmount: 5000)]
        let featureData = try! JSONEncoder().encode(featureSettings)
        let featureReloaded = try! JSONDecoder().decode(SalarySettings.self, from: featureData)
        precondition(featureReloaded.privacyMode && featureReloaded.afterWorkReminderEnabled
                     && featureReloaded.afterWorkReminderHour == 18 && featureReloaded.afterWorkReminderMinute == 30,
                     "隐私模式或下班提醒配置持久化失败")
        precondition(featureReloaded.wishList.count == 1 && featureReloaded.wishList[0].name == "旅行"
                     && featureReloaded.wishList[0].targetAmount == 20000 && featureReloaded.wishList[0].savedAmount == 5000,
                     "愿望清单配置持久化失败")

        var familySettings = migrated
        familySettings.familyMembers = [
            FamilySalaryMember(name: "伴侣", monthlySalary: 18000, yearEndBonus: 30000),
            FamilySalaryMember(name: "父亲", monthlySalary: 9000)
        ]
        familySettings.windowLocked = true
        let familyData = try! JSONEncoder().encode(familySettings)
        let familyReloaded = try! JSONDecoder().decode(SalarySettings.self, from: familyData)
        precondition(familyReloaded.familyMembers.count == 2
                     && familyReloaded.familyMembers[0].name == "伴侣"
                     && familyReloaded.familyMembers[0].monthlySalary == 18000
                     && familyReloaded.familyMembers[0].yearEndBonus == 30000
                     && familyReloaded.familyMembers[1].name == "父亲"
                     && familyReloaded.familyMembers[1].monthlySalary == 9000,
                     "家庭成员姓名和月薪配置持久化失败")
        precondition(familyReloaded.windowLocked, "窗口锁定状态持久化失败")
        let legacyMemberJSON = #"{"name":"旧成员","monthlySalary":12000}"#.data(using: .utf8)!
        let legacyMember = try! JSONDecoder().decode(FamilySalaryMember.self, from: legacyMemberJSON)
        precondition(legacyMember.monthlySalary == 12000 && legacyMember.socialInsuranceBase == 12000
                     && legacyMember.housingFundBase == 12000 && !legacyMember.useAfterTaxSalary,
                     "旧家庭成员配置迁移到独立税后档案失败")
        var partner = FamilySalaryMember(name: "伴侣", monthlySalary: 18000, yearEndBonus: 12000)
        partner.useAfterTaxSalary = true
        partner.socialInsuranceBase = 15000
        partner.socialInsuranceRate = 10.5
        partner.housingFundBase = 18000
        partner.housingFundRate = 5
        partner.monthlySpecialDeductions = 2000
        familySettings.familyMembers = [partner]
        let independentTaxData = try! JSONEncoder().encode(familySettings)
        let independentTaxReloaded = try! JSONDecoder().decode(SalarySettings.self, from: independentTaxData)
        let savedPartner = independentTaxReloaded.familyMembers[0]
        precondition(savedPartner.useAfterTaxSalary && savedPartner.socialInsuranceBase == 15000
                     && savedPartner.socialInsuranceRate == 10.5 && savedPartner.housingFundBase == 18000
                     && savedPartner.housingFundRate == 5 && savedPartner.monthlySpecialDeductions == 2000,
                     "家庭成员独立税后参数持久化失败")
        partner.workdays = [2, 3, 4, 5, 6, 7]
        partner.startHour = 10
        partner.startMinute = 30
        partner.endHour = 19
        partner.endMinute = 30
        partner.lunchStartHour = 13
        partner.lunchEndHour = 14
        var secondMember = FamilySalaryMember(name: "双休成员", monthlySalary: 12000)
        secondMember.workdays = [2, 3, 4, 5, 6]
        familySettings.familyMembers = [partner, secondMember]
        let independentScheduleData = try! JSONEncoder().encode(familySettings)
        let independentScheduleReloaded = try! JSONDecoder().decode(SalarySettings.self, from: independentScheduleData)
        let scheduledPartner = independentScheduleReloaded.familyMembers[0]
        let scheduledSecondMember = independentScheduleReloaded.familyMembers[1]
        precondition(scheduledPartner.workdays == [2, 3, 4, 5, 6, 7]
                     && scheduledSecondMember.workdays == [2, 3, 4, 5, 6],
                     "不同家庭成员的每周工作制度必须独立持久化，不能互相覆盖")
        precondition(scheduledPartner.startHour == 10 && scheduledPartner.startMinute == 30
                     && scheduledPartner.endHour == 19 && scheduledPartner.endMinute == 30
                     && scheduledPartner.lunchStartHour == 13 && scheduledPartner.lunchEndHour == 14,
                     "家庭成员独立工作时间持久化失败")
        var partnerSchedule = SalarySettings()
        partnerSchedule.monthlySalary = scheduledPartner.monthlySalary
        partnerSchedule.workdays = scheduledPartner.workdays
        partnerSchedule.startHour = scheduledPartner.startHour
        partnerSchedule.startMinute = scheduledPartner.startMinute
        partnerSchedule.endHour = scheduledPartner.endHour
        partnerSchedule.endMinute = scheduledPartner.endMinute
        partnerSchedule.lunchStartHour = scheduledPartner.lunchStartHour
        partnerSchedule.lunchEndHour = scheduledPartner.lunchEndHour
        let beforePartnerShift = SalaryCalculator.snapshot(settings: partnerSchedule, now: date(2026, 11, 24, 10), calendar: calendar)
        let duringPartnerShift = SalaryCalculator.snapshot(settings: partnerSchedule, now: date(2026, 11, 24, 11), calendar: calendar)
        precondition(beforePartnerShift.progress == 0 && duringPartnerShift.progress > 0,
                     "家庭成员应按自己的上班时间计算收入进度")
        let partnerSaturday = SalaryCalculator.snapshot(settings: partnerSchedule, now: date(2026, 11, 28, 11), calendar: calendar)
        precondition(partnerSaturday.isWorkday, "家庭成员应按自己的每周工作制度将周六识别为工作日")
        var displaySettings = SalarySettings()
        displaySettings.showSecondRate = true
        displaySettings.showAnnualSalary = true
        displaySettings.progressBarStyle = .segmented
        displaySettings.lunchBreakEnabled = true
        let displayRoundTrip = try! JSONDecoder().decode(SalarySettings.self, from: JSONEncoder().encode(displaySettings))
        precondition(displayRoundTrip.showSecondRate && displayRoundTrip.showAnnualSalary
                     && displayRoundTrip.progressBarStyle == .segmented && displayRoundTrip.lunchBreakEnabled,
                     "秒薪、年薪、进度条样式和午休开关持久化失败")
        precondition(abs(morning.secondRate - morning.hourlyRate / 3600) < 0.000001
                     && abs(morning.annualSalary - settings.monthlySalary * 12) < 0.01,
                     "秒薪或年薪计算错误")
        var bonusSettings = settings
        bonusSettings.yearEndBonus = 25000
        let bonusSnapshot = SalaryCalculator.snapshot(settings: bonusSettings, now: date(2026, 11, 24, 10), calendar: calendar)
        precondition(abs(bonusSnapshot.annualSalary - (settings.monthlySalary * 12 + 25000)) < 0.01
                     && abs(bonusSnapshot.dailyRate - morning.dailyRate) < 0.000001,
                     "年终奖应计入年薪，但不能改变日薪")
        var partnerCalculation = SalarySettings()
        partnerCalculation.monthlySalary = savedPartner.monthlySalary
        partnerCalculation.yearEndBonus = savedPartner.yearEndBonus
        partnerCalculation.socialInsuranceBase = savedPartner.socialInsuranceBase
        partnerCalculation.socialInsuranceRate = savedPartner.socialInsuranceRate
        partnerCalculation.housingFundBase = savedPartner.housingFundBase
        partnerCalculation.housingFundRate = savedPartner.housingFundRate
        partnerCalculation.monthlySpecialDeductions = savedPartner.monthlySpecialDeductions
        partnerCalculation.useAfterTaxSalary = savedPartner.useAfterTaxSalary
        let partnerSnapshot = SalaryCalculator.snapshot(settings: partnerCalculation, now: date(2026, 11, 24, 10), calendar: calendar)
        precondition(partnerSnapshot.netMonthlySalary < savedPartner.monthlySalary && partnerSnapshot.tax >= 0
                     && abs(partnerSnapshot.annualSalary - (partnerSnapshot.netMonthlySalary * 12 + savedPartner.yearEndBonus)) < 0.01,
                     "家庭成员独立税后工资或年终奖计算失败")

        print("通过：新增独立工作时间、秒薪/年薪开关与计算回归检查；并覆盖薪资计算、节假日与补班、配置兼容、家庭成员税后档案、窗口锁定、愿望清单、提醒、隐私模式、动画及多语言配置")
    }
}
