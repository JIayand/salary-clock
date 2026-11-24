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

    func configureAfterWorkReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["salary-clock-after-work"])
        guard settings.afterWorkReminderEnabled else { return }
        let reminderHour = min(23, max(0, settings.afterWorkReminderHour))
        let reminderMinute = min(59, max(0, settings.afterWorkReminderMinute))
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "下班时间到了"
            content.body = "今天的工作已经结束，记得休息。"
            content.sound = .default
            var components = DateComponents()
            components.hour = reminderHour
            components.minute = reminderMinute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "salary-clock-after-work", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: storageKey)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
