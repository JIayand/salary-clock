import Foundation
import SwiftUI
@preconcurrency import UserNotifications

@MainActor
final class SalaryClockModel: ObservableObject {
    @Published var settings: SalarySettings {
        didSet {
            save()
            if oldValue.afterWorkReminderEnabled != settings.afterWorkReminderEnabled
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
    private let appGroupID = "group.com.jyd.salaryclock"

    init() {
        let sharedDefaults = UserDefaults(suiteName: appGroupID)
        let data = sharedDefaults?.data(forKey: storageKey) ?? UserDefaults.standard.data(forKey: storageKey)
        if let data, let saved = try? JSONDecoder().decode(SalarySettings.self, from: data) {
            settings = saved
        } else {
            settings = SalarySettings()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
        configureAfterWorkReminder()
    }

    var snapshot: SalarySnapshot {
        SalaryCalculator.snapshot(settings: settings, now: now)
    }

    func snapshot(for member: FamilySalaryMember) -> SalarySnapshot {
        var memberSettings = settings
        memberSettings.monthlySalary = max(0, member.monthlySalary)
        memberSettings.socialInsuranceBase = max(0, member.monthlySalary)
        memberSettings.housingFundBase = max(0, member.monthlySalary)
        memberSettings.useAfterTaxSalary = false
        return SalaryCalculator.snapshot(settings: memberSettings, now: now)
    }

    func configureAfterWorkReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["salary-clock-after-work"])
        guard settings.afterWorkReminderEnabled else {
            reminderStatus = "提醒已关闭"
            return
        }

        let reminderHour = min(23, max(0, settings.afterWorkReminderHour))
        let reminderMinute = min(59, max(0, settings.afterWorkReminderMinute))
        reminderStatus = "正在配置提醒…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard try await requestNotificationAuthorization() else {
                    reminderStatus = "通知权限未开启，请在 macOS 系统设置中允许"
                    return
                }

                let content = UNMutableNotificationContent()
                content.title = "下班时间到了"
                content.body = "今天的工作已经结束，记得休息。"
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
                reminderStatus = String(format: "已设置每天 %02d:%02d 提醒", reminderHour, reminderMinute)
            } catch {
                reminderStatus = "提醒配置失败：\(error.localizedDescription)"
            }
        }
    }

    func sendTestReminder() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let center = UNUserNotificationCenter.current()
            do {
                guard try await requestNotificationAuthorization() else {
                    reminderStatus = "通知权限未开启，请在 macOS 系统设置中允许"
                    return
                }
                let content = UNMutableNotificationContent()
                content.title = "薪资时钟通知测试"
                content.body = "如果你看到了这条通知，说明 macOS 通知发送正常。"
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "salary-clock-test-\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )
                try await center.add(request)
                reminderStatus = "测试通知已发送"
            } catch {
                reminderStatus = "测试通知发送失败：\(error.localizedDescription)"
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

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: storageKey)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
