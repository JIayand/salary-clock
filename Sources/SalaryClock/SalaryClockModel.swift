import Foundation
import SwiftUI
import WidgetKit
@preconcurrency import UserNotifications

@MainActor
final class SalaryClockModel: ObservableObject {
    static let shared = SalaryClockModel()
    @Published var settings: SalarySettings {
        didSet {
            if oldValue.effectiveWorkTrackingEnabled != settings.effectiveWorkTrackingEnabled {
                settings.effectiveWorkTrackingStartedAt = settings.effectiveWorkTrackingEnabled ? Date() : nil
            }
            save()
            if oldValue.effectiveWorkTrackingEnabled && !settings.effectiveWorkTrackingEnabled && activeBreak != nil {
                endBreak()
            }
            if oldValue.alwaysOnTop != settings.alwaysOnTop {
                NotificationCenter.default.post(name: .salaryClockWindowLevelChanged, object: nil)
            }
            if oldValue.language != settings.language
                || oldValue.afterWorkReminderEnabled != settings.afterWorkReminderEnabled
                || oldValue.afterWorkReminderHour != settings.afterWorkReminderHour
                || oldValue.afterWorkReminderMinute != settings.afterWorkReminderMinute {
                configureAfterWorkReminder()
            }
        }
    }
    @Published var now = Date()
    @Published var reminderStatus = "尚未配置"
    @Published private(set) var breakRecords: [WorkBreakRecord] = []
    @Published private(set) var activeBreak: WorkBreakRecord?
    @Published private(set) var overtimeStartedAt: Date?
    @Published private(set) var overtimeSessions: [OvertimeSession] = []
    @Published private(set) var workdayClosedDateKey: Int?
    private var reminderConfigurationID = UUID()
    private var timer: Timer?

    private let storageKey = "salary-clock.settings.v1"
    private let appGroupID = "WXFKXAFBJ8.salaryclock"
    private let legacyBundleID = "com.jyd.salaryclock"
    private let breakRecordsKey = "salary-clock.work-break-records.v1"
    private let activeBreakKey = "salary-clock.active-work-break.v1"
    private let overtimeStartedAtKey = "salary-clock.overtime-started-at.v1"
    private let overtimeSessionsKey = "salary-clock.overtime-sessions.v1"
    private let workdayClosedDateKeyName = "salary-clock.workday-closed-date.v1"

    init() {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        let legacyDefaults = UserDefaults(suiteName: legacyBundleID)
        Self.migrateLegacyPreferences(from: legacyDefaults, to: sharedDefaults)

        let sharedData = sharedDefaults?.data(forKey: storageKey)
        let data = sharedData
            ?? legacyDefaults?.data(forKey: storageKey)
            ?? UserDefaults.standard.data(forKey: storageKey)
        if let data, let saved = try? JSONDecoder().decode(SalarySettings.self, from: data) {
            settings = saved
            // The bundle identifier changed for Personal Team signing. Copy the
            // original app's complete settings into the new team-scoped group.
            if sharedData == nil {
                save()
            }
        } else {
            settings = SalarySettings()
        }
        if settings.effectiveWorkTrackingEnabled && settings.effectiveWorkTrackingStartedAt == nil {
            settings.effectiveWorkTrackingStartedAt = Date()
            save()
        }
        loadBreakRecords(sharedDefaults: sharedDefaults)
        loadOvertimeState(sharedDefaults: sharedDefaults)
        closeBreakAtDayBoundaryIfNeeded()
        closeOvertimeAtDayBoundaryIfNeeded()
        // A menu (for example, the floating widget's “开始休息” menu) switches
        // the main run loop into event-tracking mode. Register in .common so
        // live salary/progress updates continue while the menu is open.
        let clockTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.now = Date()
                self.closeBreakAtDayBoundaryIfNeeded()
                self.closeOvertimeAtDayBoundaryIfNeeded()
            }
        }
        timer = clockTimer
        RunLoop.main.add(clockTimer, forMode: .common)
        configureAfterWorkReminder()
        // 启动时先原子写入完整共享快照，再请求 WidgetKit 重新读取。
        syncWidgetSharedState()
    }

    var snapshot: SalarySnapshot {
        var value = SalaryCalculator.snapshot(settings: settings, now: now)
        let overtime = overtimeStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        value = SalarySnapshot(
            earned: value.earned, progress: value.progress,
            todayWorkSeconds: value.todayWorkSeconds, elapsedWorkSeconds: value.elapsedWorkSeconds,
            monthlyWorkdays: value.monthlyWorkdays, isWorkday: value.isWorkday,
            isWorkingNow: value.isWorkingNow && overtimeStartedAt == nil,
            remainingSeconds: value.remainingSeconds, overtimeSeconds: overtime,
            isOvertime: overtimeStartedAt != nil, isPublicHoliday: value.isPublicHoliday,
            isMakeupWorkday: value.isMakeupWorkday, dailyRate: value.dailyRate,
            hourlyRate: value.hourlyRate, weekEarned: value.weekEarned,
            monthEarned: value.monthEarned, tax: value.tax, netMonthlySalary: value.netMonthlySalary,
            secondRate: value.secondRate, annualSalary: value.annualSalary
        )
        return value
    }

    var canChooseAfterWork: Bool {
        guard snapshot.isWorkday, overtimeStartedAt == nil else { return false }
        let calendar = Calendar.current
        let end = calendar.date(bySettingHour: settings.endHour, minute: settings.endMinute, second: 0, of: now) ?? now
        let key = ChinaWorkCalendar.dateKey(now, calendar: calendar)
        return now >= end && workdayClosedDateKey != key
    }

    func finishWorkday() {
        guard canChooseAfterWork else { return }
        workdayClosedDateKey = ChinaWorkCalendar.dateKey(now, calendar: .current)
        persistOvertimeState()
    }

    func startOvertime() {
        guard canChooseAfterWork else { return }
        overtimeStartedAt = now
        persistOvertimeState()
    }

    func endOvertime() {
        finishOvertime(at: now)
    }

    private func finishOvertime(at date: Date) {
        guard let startedAt = overtimeStartedAt else { return }
        let endedAt = max(startedAt, date)
        overtimeSessions.insert(OvertimeSession(id: UUID(), startTime: startedAt, endTime: endedAt), at: 0)
        if overtimeSessions.count > 2000 { overtimeSessions = Array(overtimeSessions.prefix(2000)) }
        overtimeStartedAt = nil
        workdayClosedDateKey = ChinaWorkCalendar.dateKey(endedAt, calendar: .current)
        persistOvertimeState()
    }

    private func closeOvertimeAtDayBoundaryIfNeeded() {
        guard let startedAt = overtimeStartedAt,
              !Calendar.current.isDate(startedAt, inSameDayAs: now),
              let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: startedAt)) else { return }
        finishOvertime(at: nextDay)
    }

    private func loadOvertimeState(sharedDefaults: UserDefaults?) {
        let defaults = sharedDefaults ?? .standard
        overtimeStartedAt = defaults.object(forKey: overtimeStartedAtKey) as? Date
        workdayClosedDateKey = defaults.object(forKey: workdayClosedDateKeyName) as? Int
        if let data = defaults.data(forKey: overtimeSessionsKey),
           let sessions = try? JSONDecoder().decode([OvertimeSession].self, from: data) {
            overtimeSessions = sessions.sorted { $0.startTime > $1.startTime }
        }
    }

    private func persistOvertimeState() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        if let overtimeStartedAt { defaults.set(overtimeStartedAt, forKey: overtimeStartedAtKey) }
        else { defaults.removeObject(forKey: overtimeStartedAtKey) }
        if let workdayClosedDateKey { defaults.set(workdayClosedDateKey, forKey: workdayClosedDateKeyName) }
        else { defaults.removeObject(forKey: workdayClosedDateKeyName) }
        if let data = try? JSONEncoder().encode(overtimeSessions) { defaults.set(data, forKey: overtimeSessionsKey) }
        syncWidgetSharedState()
    }

    func snapshot(for member: FamilySalaryMember) -> SalarySnapshot {
        var memberSettings = settings
        memberSettings.monthlySalary = max(0, member.monthlySalary)
        memberSettings.yearEndBonus = max(0, member.yearEndBonus)
        memberSettings.workdays = member.workdays
        memberSettings.socialInsuranceBase = max(0, member.socialInsuranceBase)
        memberSettings.socialInsuranceRate = max(0, member.socialInsuranceRate)
        memberSettings.housingFundBase = max(0, member.housingFundBase)
        memberSettings.housingFundRate = max(0, member.housingFundRate)
        memberSettings.monthlySpecialDeductions = max(0, member.monthlySpecialDeductions)
        memberSettings.useAfterTaxSalary = member.useAfterTaxSalary
        memberSettings.startHour = member.startHour
        memberSettings.startMinute = member.startMinute
        memberSettings.endHour = member.endHour
        memberSettings.endMinute = member.endMinute
        memberSettings.lunchStartHour = member.lunchStartHour
        memberSettings.lunchStartMinute = member.lunchStartMinute
        memberSettings.lunchEndHour = member.lunchEndHour
        memberSettings.lunchEndMinute = member.lunchEndMinute
        memberSettings.lunchBreakEnabled = member.lunchBreakEnabled
        return SalaryCalculator.snapshot(settings: memberSettings, now: now)
    }


    // MARK: - Effective work-time tracking

    func startBreak(_ type: WorkBreakType) {
        guard settings.effectiveWorkTrackingEnabled, activeBreak == nil else { return }
        let record = WorkBreakRecord(
            id: UUID(),
            type: type,
            startTime: Date(),
            endTime: nil,
            deductFromWork: shouldDeduct(type)
        )
        activeBreak = record
        persistBreakState()
    }

    @discardableResult
    func addBreak(_ type: WorkBreakType, start: Date, end: Date) -> Bool {
        guard settings.effectiveWorkTrackingEnabled, end > start, end <= now else { return false }
        let overlapsSaved = breakRecords.contains { record in
            let recordEnd = record.endTime ?? now
            return start < recordEnd && end > record.startTime
        }
        let overlapsActive = activeBreak.map { start < now && end > $0.startTime } ?? false
        guard !overlapsSaved, !overlapsActive else { return false }
        let record = WorkBreakRecord(
            id: UUID(),
            type: type,
            startTime: start,
            endTime: end,
            deductFromWork: shouldDeduct(type)
        )
        breakRecords.append(record)
        breakRecords.sort { $0.startTime > $1.startTime }
        if breakRecords.count > 1000 { breakRecords = Array(breakRecords.prefix(1000)) }
        persistBreakState()
        return true
    }

    func endBreak(at date: Date = Date()) {
        guard var record = activeBreak else { return }
        record.endTime = max(record.startTime, date)
        breakRecords.append(record)
        breakRecords.sort { $0.startTime > $1.startTime }
        if breakRecords.count > 1000 { breakRecords = Array(breakRecords.prefix(1000)) }
        activeBreak = nil
        persistBreakState()
    }

    func deleteBreak(_ record: WorkBreakRecord) {
        breakRecords.removeAll { $0.id == record.id }
        persistBreakState()
    }

    func breakSeconds(on date: Date, deductOnly: Bool = false) -> TimeInterval {
        WorkBreakCalculator.combinedBreakSeconds(
            records: breakRecords,
            activeRecord: activeBreak,
            now: now,
            on: date,
            settings: settings,
            deductOnly: deductOnly
        )
    }

    var todayBreakSeconds: TimeInterval { breakSeconds(on: now) }
    var todayActualBreakSeconds: TimeInterval { actualBreakSeconds(on: now) }
    var todayEstimatedBreakSeconds: TimeInterval {
        guard settings.effectiveWorkTrackingEnabled,
              let startedAt = settings.effectiveWorkTrackingStartedAt,
              Calendar.current.startOfDay(for: now) >= Calendar.current.startOfDay(for: startedAt),
              SalaryCalculator.snapshot(settings: settings, now: Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now).isWorkday else { return 0 }
        return WorkBreakType.allCases.reduce(0) { $0 + Double(WorkBreakCalculator.configuredMinutes(for: $1, settings: settings)) * 60 }
    }

    func actualBreakSeconds(on date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return (breakRecords + (activeBreak.map { [$0] } ?? [])).reduce(0) { total, record in
            let recordEnd = min(record.endTime ?? now, end)
            return total + max(0, min(end, recordEnd).timeIntervalSince(max(start, record.startTime)))
        }
    }

    var todayDeductedBreakSeconds: TimeInterval { deductedWorkBreakSeconds(on: now) }

    func deductedWorkBreakSeconds(on date: Date) -> TimeInterval {
        WorkBreakCalculator.deductedWorkSeconds(
            records: breakRecords,
            activeRecord: activeBreak,
            now: now,
            on: date,
            settings: settings
        )
    }

    var todayEffectiveWorkSeconds: TimeInterval {
        max(0, snapshot.elapsedWorkSeconds - todayDeductedBreakSeconds)
    }
    var effectiveHourlyRate: Double {
        let denominator = max(0, snapshot.todayWorkSeconds - todayDeductedBreakSeconds)
        return denominator > 0 ? snapshot.dailyRate * 3600 / denominator : 0
    }

    func breakCount(on date: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        return (breakRecords + (activeBreak.map { [$0] } ?? [])).filter {
            $0.startTime < end && ($0.endTime ?? now) > start
        }.count
    }

    private func shouldDeduct(_ type: WorkBreakType) -> Bool {
        switch type {
        case .restroom: return settings.deductRestroomBreaks
        case .phone: return settings.deductPhoneBreaks
        case .shortBreak: return settings.deductShortBreaks
        case .meal: return settings.deductMealBreaks
        case .other: return settings.deductOtherBreaks
        }
    }

    private func closeBreakAtDayBoundaryIfNeeded() {
        guard let activeBreak,
              !Calendar.current.isDate(activeBreak.startTime, inSameDayAs: now),
              let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: activeBreak.startTime)) else {
            return
        }
        // An unfinished break must not leak into the next workday indefinitely.
        endBreak(at: nextDay)
    }

    private func loadBreakRecords(sharedDefaults: UserDefaults?) {
        let defaults = sharedDefaults ?? UserDefaults.standard
        if let data = defaults.data(forKey: breakRecordsKey),
           let records = try? JSONDecoder().decode([WorkBreakRecord].self, from: data) {
            breakRecords = records.sorted { $0.startTime > $1.startTime }
        }
        if let data = defaults.data(forKey: activeBreakKey),
           let record = try? JSONDecoder().decode(WorkBreakRecord.self, from: data) {
            activeBreak = record
        }
    }

    private func persistBreakState() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        if let data = try? JSONEncoder().encode(breakRecords) {
            defaults.set(data, forKey: breakRecordsKey)
        }
        if let activeBreak, let data = try? JSONEncoder().encode(activeBreak) {
            defaults.set(data, forKey: activeBreakKey)
        } else {
            defaults.removeObject(forKey: activeBreakKey)
        }
        syncWidgetSharedState()
    }

    func configureAfterWorkReminder() {
        let center = UNUserNotificationCenter.current()
        let configurationID = UUID()
        reminderConfigurationID = configurationID
        center.removePendingNotificationRequests(withIdentifiers: ["salary-clock-after-work"])
        guard settings.afterWorkReminderEnabled else {
            reminderStatus = AppLocalization.string("提醒已关闭", language: settings.language)
            return
        }

        let reminderHour = min(23, max(0, settings.afterWorkReminderHour))
        let reminderMinute = min(59, max(0, settings.afterWorkReminderMinute))
        let language = settings.language
        reminderStatus = AppLocalization.string("正在配置提醒…", language: language)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard try await requestNotificationAuthorization() else {
                    guard reminderConfigurationID == configurationID else { return }
                    reminderStatus = AppLocalization.string("通知权限未开启，请在 macOS 系统设置中允许", language: language)
                    return
                }
                // Settings changes can start multiple authorization tasks. Only the
                // latest configuration is allowed to install a pending request.
                guard reminderConfigurationID == configurationID,
                      settings.afterWorkReminderEnabled,
                      settings.afterWorkReminderHour == reminderHour,
                      settings.afterWorkReminderMinute == reminderMinute else { return }

                let content = UNMutableNotificationContent()
                content.title = AppLocalization.string("下班时间到了", language: language)
                content.body = AppLocalization.string("今天的工作已经结束，记得休息。", language: language)
                content.sound = .default
                content.threadIdentifier = "salary-clock-reminders"

                var components = DateComponents()
                components.calendar = Calendar(identifier: .gregorian)
                components.timeZone = .autoupdatingCurrent
                components.hour = reminderHour
                components.minute = reminderMinute
                components.second = 0
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "salary-clock-after-work",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
                guard reminderConfigurationID == configurationID else {
                    center.removePendingNotificationRequests(withIdentifiers: ["salary-clock-after-work"])
                    return
                }
                let pending = await center.pendingNotificationRequests()
                guard pending.contains(where: { $0.identifier == "salary-clock-after-work" }) else {
                    reminderStatus = AppLocalization.string("提醒配置失败：系统未保留定时任务", language: language)
                    return
                }
                reminderStatus = String(format: AppLocalization.string("已设置每天 %02d:%02d 提醒", language: language), reminderHour, reminderMinute)
            } catch {
                guard reminderConfigurationID == configurationID else { return }
                reminderStatus = AppLocalization.string("提醒配置失败：%@", language: language).replacingOccurrences(of: "%@", with: error.localizedDescription)
            }
        }
    }

    func sendTestReminder() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let center = UNUserNotificationCenter.current()
            do {
                guard try await requestNotificationAuthorization() else {
                    reminderStatus = AppLocalization.string("通知权限未开启，请在 macOS 系统设置中允许", language: settings.language)
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = AppLocalization.string("薪资时钟通知测试", language: settings.language)
                content.body = AppLocalization.string("如果你看到了这条通知，说明 macOS 通知发送正常。", language: settings.language)
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "salary-clock-test-\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
                try await center.add(request)
                reminderStatus = AppLocalization.string("测试通知已发送", language: settings.language)
            } catch {
                reminderStatus = AppLocalization.string("测试通知发送失败：%@", language: settings.language).replacingOccurrences(of: "%@", with: error.localizedDescription)
            }
        }
    }

    private func requestNotificationAuthorization() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        @unknown default:
            return false
        }
    }


    private static func migrateLegacyPreferences(
        from legacyDefaults: UserDefaults?,
        to sharedDefaults: UserDefaults?
    ) {
        guard let legacyDefaults else { return }
        let simpleKeys = [
            "salary-clock.hasSeenSetupGuide",
            "salary-clock.notification-icon-revision"
        ]
        for key in simpleKeys where UserDefaults.standard.object(forKey: key) == nil {
            if let value = legacyDefaults.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }

        // The earlier Xcode test build may already have stored a temporary
        // default position under the new bundle ID. Prefer the real legacy
        // position unless the new shared suite already contains one.
        let positionKey = "salary-clock.floating-widget.position"
        if sharedDefaults?.array(forKey: positionKey) == nil,
           let legacyPosition = legacyDefaults.array(forKey: positionKey) {
            sharedDefaults?.set(legacyPosition, forKey: positionKey)
            UserDefaults.standard.set(legacyPosition, forKey: positionKey)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: storageKey)
        UserDefaults.standard.set(data, forKey: storageKey)
        syncWidgetSharedState()
    }

    @discardableResult
    private func syncWidgetSharedState() -> Bool {
        // Do not make WidgetKit depend on cross-process CFPrefs suite reads.
        // Replace one complete snapshot atomically before asking WidgetKit to refresh.
        let didWrite = SalaryClockWidgetSharedStore.write(
            settings: settings,
            breakRecords: breakRecords,
            activeBreak: activeBreak,
            overtimeStartedAt: overtimeStartedAt
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "SalaryClockWidget")
        return didWrite
    }
}
