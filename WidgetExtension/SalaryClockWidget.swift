import SwiftUI
import WidgetKit

private let salaryAppGroup = "WXFKXAFBJ8.salaryclock"
private let salarySettingsKey = "salary-clock.settings.v1"
private let salaryWidgetKind = "SalaryClockWidget"

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
        let settings = loadSettings()
        let calendar = Calendar.current
        let now = Date()
        let minuteStart = calendar.dateInterval(of: .minute, for: now)?.start ?? now

        // 预先提供未来 60 分钟的分钟级快照。WidgetKit 可能合并或延后展示，
        // 因此这是尽可能及时的更新，不代表秒级实时刷新。
        let entries = (0...60).compactMap { offset -> SalaryClockWidgetEntry? in
            guard let date = calendar.date(byAdding: .minute, value: offset, to: minuteStart) else {
                return nil
            }
            return makeEntry(date: date, settings: settings)
        }

        let refreshDate = entries.last?.date.addingTimeInterval(60) ?? now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func loadSettings() -> SalarySettings {
        guard let data = UserDefaults(suiteName: salaryAppGroup)?.data(forKey: salarySettingsKey),
              let settings = try? JSONDecoder().decode(SalarySettings.self, from: data) else {
            return SalarySettings()
        }
        return settings
    }

    private func makeEntry(date: Date, settings: SalarySettings) -> SalaryClockWidgetEntry {
        SalaryClockWidgetEntry(
            date: date,
            settings: settings,
            snapshot: SalaryCalculator.snapshot(settings: settings, now: date)
        )
    }
}

private struct FamilyWidgetRow: Identifiable {
    let id: UUID
    let name: String
    let snapshot: SalarySnapshot
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int
}

/// WidgetKit controls timeline reloads, but SwiftUI TimelineView can redraw
/// time-derived content more frequently while the widget is actively rendered.
/// The system may throttle this schedule; a five-second interval is best-effort,
/// not a guaranteed real-time refresh contract.
struct SalaryClockWidgetView: View {
    let entry: SalaryClockWidgetEntry

    var body: some View {
        TimelineView(.periodic(from: entry.date, by: 5)) { context in
            let liveEntry = SalaryClockWidgetEntry(
                date: context.date,
                settings: entry.settings,
                snapshot: SalaryCalculator.snapshot(settings: entry.settings, now: context.date)
            )
            SalaryClockWidgetContent(entry: liveEntry)
                // Widget 扩展必须显式采用系统当前语言环境，不能依赖扩展包的开发语言回退值。
                .environment(\.locale, Locale.autoupdatingCurrent)
        }
        .environment(\.locale, Locale.autoupdatingCurrent)
    }
}

private struct SalaryClockWidgetContent: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalaryClockWidgetEntry

    private var language: AppLanguage { entry.settings.language }

    private var foreground: Color {
        switch entry.settings.theme {
        case .paper: return Color(red: 0.13, green: 0.16, blue: 0.19)
        case .graphite: return Color(red: 0.91, green: 0.92, blue: 0.94)
        default: return Color.white.opacity(0.94)
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
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemExtraLarge:
                extraLargeLayout
            default:
                largeLayout
            }
        }
        // 先让内容根视图占满 WidgetKit 提供的完整尺寸，再设置内部留白。
        // medium 布局此前缺少根级 max frame，容易让系统默认底色从四周露出。
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(family == .systemSmall ? 14 : 18)
        // 使用可延伸至安全区域外的容器背景，避免内容区与 Widget 外壳之间
        // 出现一圈系统默认灰色底色；不额外叠加 .background 或描边。
        .containerBackground(for: .widget) {
            background.ignoresSafeArea(.all)
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(valueCaption)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(foreground.opacity(0.56))
            Text(primaryValue)
                .font(.system(size: 25, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .padding(.top, 3)
            if entry.settings.mode == .money {
                Text(progressText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.72))
                    .padding(.top, 7)
            }
            if entry.settings.showProgress {
                progressBar(height: 5)
                    .padding(.top, 8)
            }
            Spacer(minLength: 8)
            Text(scheduleText)
                .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                Text(valueCaption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(foreground.opacity(0.56))
                    .padding(.top, 15)
                Text(primaryValue)
                    .font(.system(size: 31, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .padding(.top, 3)
                if entry.settings.mode == .money {
                    Text(progressText)
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.68))
                        .padding(.top, 7)
                }
                if entry.settings.showProgress {
                    progressBar(height: 5)
                        .padding(.top, 8)
                }
                Spacer(minLength: 8)
                Text(scheduleText)
                    .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(foreground.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 5)

            VStack(alignment: .leading, spacing: 15) {
                ForEach(Array(visibleStats.prefix(2).enumerated()), id: \.offset) { _, stat in
                    statView(stat, compact: false)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 112, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(valueCaption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(foreground.opacity(0.56))
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.38))
            }

            Text(primaryValue)
                .font(.system(size: 43, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.top, 5)

            if entry.settings.mode == .money {
                Text(progressText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.72))
                    .padding(.top, 7)
            }

            if entry.settings.showProgress {
                progressBar(height: 6)
                    .padding(.top, 10)
            }

            Text(scheduleText)
                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.55))
                .padding(.top, 9)

            if entry.settings.showWorkDuration {
                workDurationLine
                    .padding(.top, 11)
            }

            Rectangle()
                .fill(foreground.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 19)

            let stats = visibleStats
            if !stats.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                          alignment: .leading, spacing: 22) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                        statView(stat, compact: false)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var extraLargeLayout: some View {
        GeometryReader { proxy in
            let isWide = proxy.size.width > proxy.size.height * 1.18
            Group {
                if isWide {
                    HStack(alignment: .top, spacing: 18) {
                        personalOverview
                            .frame(width: proxy.size.width * 0.34)
                        Rectangle()
                            .fill(foreground.opacity(0.12))
                            .frame(width: 1)
                        familyOverview(columns: 2)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        personalOverview
                            .fixedSize(horizontal: false, vertical: true)
                        Rectangle()
                            .fill(foreground.opacity(0.12))
                            .frame(height: 1)
                        familyOverview(columns: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var personalOverview: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("今日已赚")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.62))
                Spacer()
                Text(entry.date, style: .date)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(foreground.opacity(0.4))
            }
            Text(primaryValue)
                .font(.system(size: 37, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            Text(progressText)
                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.72))
            if entry.settings.showProgress {
                progressBar(height: 7)
            }
            if entry.settings.showWorkDuration {
                workDurationLine
            }
            Text(scheduleText)
                .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.55))
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 13) {
                ForEach(Array(visibleStats.enumerated()), id: \.offset) { _, stat in
                    statView(stat, compact: false)
                }
            }
            .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func familyOverview(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("家庭收入总览")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(foreground)
                    Text("本人及家庭成员 · 今日收入与工作进度")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.48))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("家庭今日合计")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.5))
                    Text(familyTotalText)
                        .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
            let rows = familyRows
            if rows.count <= 1 {
                Text("在应用设置的「薪资与家庭」中添加成员，即可查看全家收入")
                    .font(.system(size: 10))
                    .foregroundStyle(foreground.opacity(0.5))
                Spacer(minLength: 0)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .topLeading), count: columns), alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in
                        familyMemberCard(row)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var familyRows: [FamilyWidgetRow] {
        var rows = [FamilyWidgetRow(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "本人",
            snapshot: entry.snapshot,
            startHour: entry.settings.startHour,
            startMinute: entry.settings.startMinute,
            endHour: entry.settings.endHour,
            endMinute: entry.settings.endMinute
        )]
        rows += entry.settings.familyMembers.map { member in
            var settings = entry.settings
            settings.monthlySalary = max(0, member.monthlySalary)
            settings.yearEndBonus = max(0, member.yearEndBonus)
            settings.workdays = member.workdays
            settings.socialInsuranceBase = max(0, member.socialInsuranceBase)
            settings.socialInsuranceRate = max(0, member.socialInsuranceRate)
            settings.housingFundBase = max(0, member.housingFundBase)
            settings.housingFundRate = max(0, member.housingFundRate)
            settings.monthlySpecialDeductions = max(0, member.monthlySpecialDeductions)
            settings.useAfterTaxSalary = member.useAfterTaxSalary
            settings.startHour = member.startHour
            settings.startMinute = member.startMinute
            settings.endHour = member.endHour
            settings.endMinute = member.endMinute
            settings.lunchStartHour = member.lunchStartHour
            settings.lunchStartMinute = member.lunchStartMinute
            settings.lunchEndHour = member.lunchEndHour
            settings.lunchEndMinute = member.lunchEndMinute
            return FamilyWidgetRow(
                id: member.id,
                name: member.name.isEmpty ? "未命名成员" : member.name,
                snapshot: SalaryCalculator.snapshot(settings: settings, now: entry.date),
                startHour: member.startHour,
                startMinute: member.startMinute,
                endHour: member.endHour,
                endMinute: member.endMinute
            )
        }
        return rows
    }

    private var familyTotalText: String {
        guard !entry.settings.privacyMode else { return "¥••••" }
        let total = familyRows.reduce(0.0) { $0 + $1.snapshot.earned }
        return String(format: "¥%.*f", entry.settings.decimals, total)
    }

    private func familyMemberCard(_ row: FamilyWidgetRow) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(row.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(foreground.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(String(format: "%.*f%%", entry.settings.percentDecimals, row.snapshot.progress * 100))
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(accent)
            }
            Text(entry.settings.privacyMode ? "¥••••" : String(format: "¥%.*f", entry.settings.decimals, row.snapshot.earned))
                .font(.system(size: 21, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(foreground.opacity(0.12))
                    Capsule().fill(accent).frame(width: proxy.size.width * min(1, max(0, row.snapshot.progress)))
                }
            }
            .frame(height: 5)
            HStack {
                Text("已工作 \(duration(row.snapshot.elapsedWorkSeconds))")
                Spacer(minLength: 3)
                Text("剩余 \(duration(row.snapshot.remainingSeconds))")
            }
            .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(foreground.opacity(0.52))
            HStack {
                Text(String(format: "上班 %02d:%02d", row.startHour, row.startMinute))
                Spacer(minLength: 3)
                Text(String(format: "下班 %02d:%02d", row.endHour, row.endMinute))
            }
            .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(foreground.opacity(0.45))
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 7) {
                familyStat("本周已赚", row.snapshot.weekEarned, visible: entry.settings.showWeekEarned)
                familyStat("本月已赚", row.snapshot.monthEarned, visible: entry.settings.showMonthEarned)
                familyStat("时薪", row.snapshot.hourlyRate, visible: entry.settings.showHourlyRate)
                familyStat("日薪", row.snapshot.dailyRate, visible: entry.settings.showDailyRate)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 11)
        .background(foreground.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @ViewBuilder
    private func familyStat(_ title: String, _ value: Double, visible: Bool) -> some View {
        if visible {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(foreground.opacity(0.45))
                Text(displayMoney(value))
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.86))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
    }

    private var progressText: String {
        let percent = String(format: "%.*f%%", entry.settings.percentDecimals, entry.snapshot.progress * 100)
        return localized("今日进度", "今日進度", "Progress") + "  " + percent
    }

    private var scheduleText: String {
        let start = String(format: "%02d:%02d", entry.settings.startHour, entry.settings.startMinute)
        let end = String(format: "%02d:%02d", entry.settings.endHour, entry.settings.endMinute)
        return localized("上班", "上班", "Start") + " " + start + "   " + localized("下班", "下班", "End") + " " + end
    }

    private var workDurationLine: some View {
        HStack(spacing: 0) {
            Text("\(localized("已工作", "已工作", "Worked"))  \(duration(entry.snapshot.elapsedWorkSeconds))")
            Spacer(minLength: 8)
            Text("\(localized("剩余", "剩餘", "Left"))  \(duration(entry.snapshot.remainingSeconds))")
        }
        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(foreground.opacity(0.52))
    }

    private func progressBar(height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(foreground.opacity(0.13))
                Capsule()
                    .fill(accent)
                    .frame(width: proxy.size.width * min(1, max(0, entry.snapshot.progress)))
            }
        }
        .frame(height: height)
    }

    private var visibleStats: [(String, String)] {
        let all: [(String, String, Bool)] = [
            (localized("本周收入", "本週收入", "This week"), displayMoney(entry.snapshot.weekEarned), entry.settings.showWeekEarned),
            (localized("本月收入", "本月收入", "This month"), displayMoney(entry.snapshot.monthEarned), entry.settings.showMonthEarned),
            (localized("时薪", "時薪", "Hourly rate"), displayMoney(entry.snapshot.hourlyRate), entry.settings.showHourlyRate),
            (localized("日薪", "日薪", "Daily rate"), displayMoney(entry.snapshot.dailyRate), entry.settings.showDailyRate)
        ]
        return all.filter { $0.2 }.map { ($0.0, $0.1) }
    }

    private func statView(_ stat: (String, String), compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(stat.0)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(foreground.opacity(0.48))
            Text(stat.1)
                .font(.system(size: compact ? 13 : 16, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var valueCaption: String {
        entry.settings.mode == .money
            ? localized("今日已赚取", "今日已賺取", "EARNED TODAY")
            : localized("今日工作进度", "今日工作進度", "TODAY'S PROGRESS")
    }

    private var primaryValue: String {
        if entry.settings.privacyMode { return "¥••••" }
        if entry.settings.mode == .percent {
            return String(format: "%.*f%%", entry.settings.percentDecimals, entry.snapshot.progress * 100)
        }
        return String(format: "¥%.*f", entry.settings.decimals, entry.snapshot.earned)
    }

    private func displayMoney(_ value: Double) -> String {
        entry.settings.privacyMode ? "¥••••" : String(format: "¥%.*f", entry.settings.decimals, value)
    }

    private func localized(_ simplified: String, _ traditional: String, _ english: String) -> String {
        switch language {
        case .simplifiedChinese: return simplified
        case .traditionalChinese: return traditional
        case .english: return english
        }
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    }
}

struct SalaryClockWidget: Widget {
    let kind = salaryWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SalaryClockWidgetProvider()) { entry in
            SalaryClockWidgetView(entry: entry)
        }
        .configurationDisplayName("薪资时钟")
        .description("查看本人及家庭成员的今日收入、进度和上下班时间")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

@main
struct SalaryClockWidgetBundle: WidgetBundle {
    var body: some Widget {
        SalaryClockWidget()
    }
}
