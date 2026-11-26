import SwiftUI
import WidgetKit

private let salaryWidgetKind = "SalaryClockWidget"

struct SalaryClockWidgetEntry: TimelineEntry {
    let date: Date
    let settings: SalarySettings
    let snapshot: SalarySnapshot
    let todayBreakSeconds: TimeInterval
}

struct SalaryClockWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> SalaryClockWidgetEntry {
        let sharedData = SalaryClockWidgetSharedData(
            settings: SalarySettings(), breakRecords: [], activeBreak: nil, overtimeStartedAt: nil
        )
        return makeEntry(date: Date(), sharedData: sharedData)
    }

    func getSnapshot(in context: Context, completion: @escaping (SalaryClockWidgetEntry) -> Void) {
        completion(makeEntry(date: Date(), sharedData: loadSharedData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SalaryClockWidgetEntry>) -> Void) {
        // Read settings and runtime records together from one atomic shared snapshot.
        let sharedData = loadSharedData()
        let calendar = Calendar.current
        let now = Date()
        let minuteStart = calendar.dateInterval(of: .minute, for: now)?.start ?? now

        // WidgetKit schedules these minute-level snapshots; the system may defer them.
        let entries = (0...60).compactMap { offset -> SalaryClockWidgetEntry? in
            guard let date = calendar.date(byAdding: .minute, value: offset, to: minuteStart) else {
                return nil
            }
            return makeEntry(date: date, sharedData: sharedData)
        }

        let refreshDate = entries.last?.date.addingTimeInterval(60) ?? now.addingTimeInterval(60 * 60)
        completion(Timeline(entries: entries, policy: .after(refreshDate)))
    }

    private func loadSharedData() -> SalaryClockWidgetSharedData {
        if let sharedData = SalaryClockWidgetSharedStore.read() {
            return sharedData
        }
        // The host app writes a complete snapshot on every launch. Defaults are
        // only a safe first-launch/corrupt-file fallback, never a partial merge.
        return SalaryClockWidgetSharedData(
            settings: SalarySettings(), breakRecords: [], activeBreak: nil, overtimeStartedAt: nil
        )
    }

    private func makeEntry(
        date: Date,
        sharedData: SalaryClockWidgetSharedData
    ) -> SalaryClockWidgetEntry {
        let settings = sharedData.settings
        let calculated = SalaryCalculator.snapshot(settings: settings, now: date)
        let overtimeSeconds = sharedData.overtimeStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        let isOvertime = sharedData.overtimeStartedAt != nil
        let snapshot = SalarySnapshot(
            earned: calculated.earned,
            progress: calculated.progress,
            todayWorkSeconds: calculated.todayWorkSeconds,
            elapsedWorkSeconds: calculated.elapsedWorkSeconds,
            monthlyWorkdays: calculated.monthlyWorkdays,
            isWorkday: calculated.isWorkday,
            isWorkingNow: calculated.isWorkingNow && !isOvertime,
            remainingSeconds: calculated.remainingSeconds,
            overtimeSeconds: overtimeSeconds,
            isOvertime: isOvertime,
            isPublicHoliday: calculated.isPublicHoliday,
            isMakeupWorkday: calculated.isMakeupWorkday,
            dailyRate: calculated.dailyRate,
            hourlyRate: calculated.hourlyRate,
            weekEarned: calculated.weekEarned,
            monthEarned: calculated.monthEarned,
            tax: calculated.tax,
            netMonthlySalary: calculated.netMonthlySalary,
            secondRate: calculated.secondRate,
            annualSalary: calculated.annualSalary
        )
        let todayBreakSeconds = WorkBreakCalculator.combinedBreakSeconds(
            records: sharedData.breakRecords,
            activeRecord: sharedData.activeBreak,
            now: date,
            on: date,
            settings: settings
        )
        return SalaryClockWidgetEntry(
            date: date,
            settings: settings,
            snapshot: snapshot,
            todayBreakSeconds: todayBreakSeconds
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

/// WidgetKit 时间线提供配置快照；视图内的 TimelineView 按秒重算金额与工作进度。
/// 系统可能节流实际刷新频率，因此秒级更新属于尽力而为，不承诺每秒必达。
struct SalaryClockWidgetView: View {
    let entry: SalaryClockWidgetEntry

    var body: some View {
        // 金额、百分比和进度条也需要随时钟推进；WidgetKit 时间线负责提供配置，
        // TimelineView 在可用时按秒重算当前工作进度，系统仍可能根据资源策略节流。
        TimelineView(.periodic(from: entry.date, by: 1)) { context in
            SalaryClockWidgetContent(entry: entry, now: context.date)
        }
        // Widget 扩展必须显式采用系统当前语言环境，不能依赖扩展包的开发语言回退值。
        .environment(\.locale, Locale.autoupdatingCurrent)
    }
}

private struct SalaryClockWidgetContent: View {
    @Environment(\.widgetFamily) private var family
    let entry: SalaryClockWidgetEntry
    let now: Date

    private var language: AppLanguage { entry.settings.language }

    /// Recalculate the live values from the same salary rules used by the host app.
    /// Preserve the explicitly started overtime session carried by the shared snapshot.
    private var liveSnapshot: SalarySnapshot {
        let calculated = SalaryCalculator.snapshot(settings: entry.settings, now: now)
        let isOvertime = entry.snapshot.isOvertime
        let overtimeSeconds = isOvertime
            ? max(0, entry.snapshot.overtimeSeconds + now.timeIntervalSince(entry.date))
            : 0
        return SalarySnapshot(
            earned: calculated.earned,
            progress: calculated.progress,
            todayWorkSeconds: calculated.todayWorkSeconds,
            elapsedWorkSeconds: calculated.elapsedWorkSeconds,
            monthlyWorkdays: calculated.monthlyWorkdays,
            isWorkday: calculated.isWorkday,
            isWorkingNow: calculated.isWorkingNow && !isOvertime,
            remainingSeconds: calculated.remainingSeconds,
            overtimeSeconds: overtimeSeconds,
            isOvertime: isOvertime,
            isPublicHoliday: calculated.isPublicHoliday,
            isMakeupWorkday: calculated.isMakeupWorkday,
            dailyRate: calculated.dailyRate,
            hourlyRate: calculated.hourlyRate,
            weekEarned: calculated.weekEarned,
            monthEarned: calculated.monthEarned,
            tax: calculated.tax,
            netMonthlySalary: calculated.netMonthlySalary,
            secondRate: calculated.secondRate,
            annualSalary: calculated.annualSalary
        )
    }

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
            if entry.settings.showWorkDuration && !liveSnapshot.isOvertime {
                compactWorkDurationLine
            }
            if liveSnapshot.isOvertime { overtimeStatusLine }
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
                if entry.settings.showWorkDuration && !liveSnapshot.isOvertime {
                    compactWorkDurationLine
                }
                if entry.settings.effectiveWorkTrackingEnabled {
                    Text("\(localized("今日预估休息", "今日預估休息", "Estimated break"))  \(duration(entry.todayBreakSeconds))")
                        .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                if liveSnapshot.isOvertime { overtimeStatusLine }
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

            if entry.settings.showWorkDuration && !liveSnapshot.isOvertime {
                workDurationLine
                    .padding(.top, 11)
            }
            if liveSnapshot.isOvertime { overtimeStatusLine.padding(.top, 7) }

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
            if entry.settings.showWorkDuration && !liveSnapshot.isOvertime {
                workDurationLine
            }
            if liveSnapshot.isOvertime { overtimeStatusLine }
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
            snapshot: liveSnapshot,
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
            settings.lunchBreakEnabled = member.lunchBreakEnabled
            return FamilyWidgetRow(
                id: member.id,
                name: member.name.isEmpty ? "未命名成员" : member.name,
                snapshot: SalaryCalculator.snapshot(settings: settings, now: now),
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
        return NumericFormatting.currency(total, fractionDigits: entry.settings.decimals)
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
                Text(NumericFormatting.number(row.snapshot.progress * 100, fractionDigits: entry.settings.percentDecimals) + "%")
                    .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.72))
            }
            Text(entry.settings.privacyMode ? "¥••••" : NumericFormatting.currency(row.snapshot.earned, fractionDigits: entry.settings.decimals))
                .font(.system(size: 21, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            SalaryProgressBar(progress: row.snapshot.progress, style: entry.settings.progressBarStyle,
                              trackColor: foreground.opacity(0.12), fillColor: accent, height: 5)
            HStack {
                if row.snapshot.isOvertime {
                    Text("已加班")
                        .foregroundStyle(overtimeColor)
                    Text(timerInterval: (entry.date.addingTimeInterval(-row.snapshot.overtimeSeconds))...Date.distantFuture, countsDown: false)
                        .foregroundStyle(overtimeColor)
                } else {
                    Text("已工作")
                    Text(timerInterval: (entry.date.addingTimeInterval(-row.snapshot.elapsedWorkSeconds))...Date.distantFuture, countsDown: false)
                    Spacer(minLength: 3)
                    Text("剩余")
                    Text(timerInterval: entry.date...(entry.date.addingTimeInterval(row.snapshot.remainingSeconds)), countsDown: true)
                }
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
        let percent = NumericFormatting.number(liveSnapshot.progress * 100, fractionDigits: entry.settings.percentDecimals) + "%"
        return localized("今日进度", "今日進度", "Progress") + "  " + percent
    }

    private var scheduleText: String {
        let start = String(format: "%02d:%02d", entry.settings.startHour, entry.settings.startMinute)
        let end = String(format: "%02d:%02d", entry.settings.endHour, entry.settings.endMinute)
        return localized("上班", "上班", "Start") + " " + start + "   " + localized("下班", "下班", "End") + " " + end
    }

    private var overtimeStatusLine: some View {
        let overtimeStart = now.addingTimeInterval(-liveSnapshot.overtimeSeconds)
        return HStack(spacing: 4) {
            Text("\(localized("已加班", "已加班", "Overtime"))")
            Text(timerInterval: overtimeStart...Date.distantFuture, countsDown: false)
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
        .foregroundStyle(overtimeColor)
    }

    /// Text(timerInterval:) is rendered by the system clock and can advance
    /// between WidgetKit timeline refreshes. Use it in every family, not only large.
    private var compactWorkDurationLine: some View {
        let workedStart = now.addingTimeInterval(-liveSnapshot.elapsedWorkSeconds)
        let workEnd = now.addingTimeInterval(liveSnapshot.remainingSeconds)
        return HStack(spacing: 3) {
            Text("\(localized("已工作", "已工作", "Worked"))")
            Text(timerInterval: workedStart...Date.distantFuture, countsDown: false)
            Spacer(minLength: 3)
            Text("\(localized("剩余", "剩餘", "Left"))")
            Text(timerInterval: now...workEnd, countsDown: true)
        }
        .font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(foreground.opacity(0.52))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }

    private var workDurationLine: some View {
        let workedStart = now.addingTimeInterval(-liveSnapshot.elapsedWorkSeconds)
        let workEnd = now.addingTimeInterval(liveSnapshot.remainingSeconds)
        return HStack(spacing: 0) {
            HStack(spacing: 3) {
                Text("\(localized("已工作", "已工作", "Worked"))")
                Text(timerInterval: workedStart...Date.distantFuture, countsDown: false)
            }
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                Text("\(localized("剩余", "剩餘", "Left"))")
                Text(timerInterval: now...workEnd, countsDown: true)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
        .foregroundStyle(foreground.opacity(0.52))
    }

    private func progressBar(height: CGFloat) -> some View {
        SalaryProgressBar(progress: liveSnapshot.progress, style: entry.settings.progressBarStyle,
                          trackColor: foreground.opacity(0.13), fillColor: accent, height: height)
    }

    private var visibleStats: [(String, String)] {
        let all: [(String, String, Bool)] = [
            (localized("本周收入", "本週收入", "This week"), displayMoney(liveSnapshot.weekEarned), entry.settings.showWeekEarned),
            (localized("本月收入", "本月收入", "This month"), displayMoney(liveSnapshot.monthEarned), entry.settings.showMonthEarned),
            (localized("时薪", "時薪", "Hourly rate"), displayMoney(liveSnapshot.hourlyRate), entry.settings.showHourlyRate),
            (localized("日薪", "日薪", "Daily rate"), displayMoney(liveSnapshot.dailyRate), entry.settings.showDailyRate),
            (localized("今日预估休息", "今日預估休息", "Estimated break"), duration(entry.todayBreakSeconds), entry.settings.effectiveWorkTrackingEnabled)
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
            return NumericFormatting.number(liveSnapshot.progress * 100, fractionDigits: entry.settings.percentDecimals) + "%"
        }
        return NumericFormatting.currency(liveSnapshot.earned, fractionDigits: entry.settings.decimals)
    }

    private var overtimeColor: Color { Color(red: 1.0, green: 0.29, blue: 0.31) }

    private func overtimeText(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%02d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
    }

    private func displayMoney(_ value: Double) -> String {
        entry.settings.privacyMode ? "¥••••" : NumericFormatting.currency(value, fractionDigits: entry.settings.decimals)
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
