import SwiftUI
import WidgetKit

private let salaryAppGroup = "group.com.jyd.salaryclock"
private let salarySettingsKey = "salary-clock.settings.v1"

struct SalaryClockWidgetEntry: TimelineEntry {
    let date: Date
    let settings: SalarySettings
    let snapshot: SalarySnapshot
}

struct SalaryClockWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalaryClockWidgetEntry {
        makeEntry(date: Date(), settings: SalarySettings())
    }

    func getSnapshot(in context: Context, completion: @escaping (SalaryClockWidgetEntry) -> Void) {
        completion(makeEntry(date: Date(), settings: loadSettings()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryClockWidgetEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(date: now, settings: loadSettings())
        // WidgetKit controls actual refresh timing; this is a refresh request, not a real-time timer.
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(15 * 60))))
    }

    private func loadSettings() -> SalarySettings {
        guard let data = UserDefaults(suiteName: salaryAppGroup)?.data(forKey: salarySettingsKey),
              let settings = try? JSONDecoder().decode(SalarySettings.self, from: data) else {
            return SalarySettings()
        }
        return settings
    }

    private func makeEntry(date: Date, settings: SalarySettings) -> SalaryClockWidgetEntry {
        let snapshot = SalaryCalculator.snapshot(settings: settings, now: date)
        return SalaryClockWidgetEntry(date: date, settings: settings, snapshot: snapshot)
    }
}

struct SalaryClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalaryClockWidgetEntry

    private var foreground: Color {
        switch entry.settings.theme {
        case .paper: return Color(red: 0.13, green: 0.16, blue: 0.19)
        case .graphite: return Color(red: 0.91, green: 0.92, blue: 0.94)
        default: return .white
        }
    }

    private var background: Color {
        switch entry.settings.theme {
        case .midnight: return Color(red: 0.075, green: 0.09, blue: 0.13)
        case .paper: return Color(red: 0.94, green: 0.93, blue: 0.89)
        case .neon: return Color(red: 0.025, green: 0.055, blue: 0.045)
        case .ocean: return Color(red: 0.055, green: 0.16, blue: 0.24)
        case .sunset: return Color(red: 0.25, green: 0.105, blue: 0.09)
        case .graphite: return Color(red: 0.12, green: 0.13, blue: 0.15)
        }
    }

    private var accent: Color {
        switch entry.settings.theme {
        case .midnight: return Color(red: 0.35, green: 0.88, blue: 0.68)
        case .paper: return Color(red: 0.12, green: 0.48, blue: 0.37)
        case .neon: return Color(red: 0.55, green: 1, blue: 0.25)
        case .ocean: return Color(red: 0.38, green: 0.82, blue: 1)
        case .sunset: return Color(red: 1, green: 0.62, blue: 0.36)
        case .graphite: return Color(red: 0.76, green: 0.81, blue: 0.9)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 11) {
            HStack(spacing: 5) {
                Circle().fill(entry.snapshot.isWorkingNow ? accent : foreground.opacity(0.35))
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(foreground.opacity(0.75))

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.settings.mode == .money ? "今日已赚取" : "今日进度")
                    .font(.system(size: 10))
                    .foregroundStyle(foreground.opacity(0.55))
                Text(primaryValue)
                    .font(.system(size: family == .systemSmall ? 23 : 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if entry.settings.showProgress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(foreground.opacity(0.12))
                        Capsule().fill(accent).frame(width: proxy.size.width * entry.snapshot.progress)
                    }
                }
                .frame(height: 4)
            }

            if family != .systemSmall && entry.settings.showWorkDuration {
                HStack {
                    Text("已工作 \(duration(entry.snapshot.elapsedWorkSeconds))")
                    Spacer()
                    Text("剩余 \(duration(entry.snapshot.remainingSeconds))")
                }
                .font(.system(size: 9, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.55))
            }

            if family != .systemSmall {
                let stats: [(String, String, Bool)] = [
                    ("本周", money(entry.snapshot.weekEarned), entry.settings.showWeekEarned),
                    ("本月", money(entry.snapshot.monthEarned), entry.settings.showMonthEarned),
                    ("时薪", money(entry.snapshot.hourlyRate), entry.settings.showHourlyRate),
                    ("日薪", money(entry.snapshot.dailyRate), entry.settings.showDailyRate)
                ].filter { $0.2 }
                if !stats.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 5) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { item in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.element.0).font(.system(size: 8)).foregroundStyle(foreground.opacity(0.5))
                                Text(item.element.1).font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                                    .foregroundStyle(foreground.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .padding(family == .systemSmall ? 12 : 15)
        .background(background)
        .containerBackground(background, for: .widget)
    }

    private var primaryValue: String {
        if entry.settings.mode == .percent {
            return String(format: "%.*f%%", entry.settings.decimals, entry.snapshot.progress * 100)
        }
        return String(format: "¥ %.*f", entry.settings.decimals, entry.snapshot.earned)
    }

    private func money(_ value: Double) -> String {
        String(format: "¥ %.2f", value)
    }

    private var statusText: String {
        if entry.snapshot.isPublicHoliday { return "法定节假日" }
        if entry.snapshot.isMakeupWorkday { return "调休补班日" }
        if entry.snapshot.isWorkingNow { return "正在为你赚钱" }
        if entry.snapshot.isWorkday { return "当前非计薪时段" }
        return "今天休息"
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    }
}

struct SalaryClockWidget: Widget {
    let kind = "SalaryClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalaryClockWidgetProvider()) { entry in
            SalaryClockWidgetView(entry: entry)
        }
        .configurationDisplayName("薪资时钟")
        .description("查看今日累计收入和工作进度")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct SalaryClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalaryClockWidget()
    }
}
