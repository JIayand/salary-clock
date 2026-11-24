import Foundation
import SwiftUI
import WidgetKit
@preconcurrency import UserNotifications

@MainActor
final class SalaryClockModel: ObservableObject {
    static let shared = SalaryClockModel()
    @Published var settings: SalarySettings {
        didSet {
            save()
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
    private var timer: Timer?

    private let storageKey = "salary-clock.settings.v1"
    private let appGroupID = "WXFKXAFBJ8.salaryclock"
    private let legacyBundleID = "com.jyd.salaryclock"

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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        configureAfterWorkReminder()
        // 启动时主动请求一次 WidgetKit 同步，避免组件继续显示上次运行留下的旧快照。
        WidgetCenter.shared.reloadTimelines(ofKind: "SalaryClockWidget")
    }

    var snapshot: SalarySnapshot {
        SalaryCalculator.snapshot(settings: settings, now: now)
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
        return SalaryCalculator.snapshot(settings: memberSettings, now: now)
    }

    func configureAfterWorkReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["salary-clock-after-work"])
        guard settings.afterWorkReminderEnabled else {
            reminderStatus = AppLocalization.string("提醒已关闭", language: settings.language)
            return
        }

        let reminderHour = min(23, max(0, settings.afterWorkReminderHour))
        let reminderMinute = min(59, max(0, settings.afterWorkReminderMinute))
        reminderStatus = AppLocalization.string("正在配置提醒…", language: settings.language)

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard try await requestNotificationAuthorization() else {
                    reminderStatus = AppLocalization.string("通知权限未开启，请在 macOS 系统设置中允许", language: settings.language)
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = AppLocalization.string("下班时间到了", language: settings.language)
                content.body = AppLocalization.string("今天的工作已经结束，记得休息。", language: settings.language)
                content.sound = .default

                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: "salary-clock-after-work",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
                reminderStatus = String(format: AppLocalization.string("已设置每天 %02d:%02d 提醒", language: settings.language), reminderHour, reminderMinute)
            } catch {
                reminderStatus = AppLocalization.string("提醒配置失败：%@", language: settings.language).replacingOccurrences(of: "%@", with: error.localizedDescription)
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
        WidgetCenter.shared.reloadTimelines(ofKind: "SalaryClockWidget")
    }
}
