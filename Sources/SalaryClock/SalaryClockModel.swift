import Foundation
import SwiftUI

@MainActor
final class SalaryClockModel: ObservableObject {
    @Published var settings: SalarySettings {
        didSet { save() }
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
    }

    var snapshot: SalarySnapshot {
        SalaryCalculator.snapshot(settings: settings, now: now)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults(suiteName: appGroupID)?.set(data, forKey: storageKey)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
