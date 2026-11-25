import SwiftUI

struct EffectiveWorkSettingsSection: View {
    @EnvironmentObject private var model: SalaryClockModel
    @State private var showingManualEntry = false

    private var recentRecords: [WorkBreakRecord] {
        Array(model.breakRecords.prefix(30))
    }

    private var weekBreakSeconds: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: model.now)
        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today) else { return 0 }
        return (0...6).reduce(0) { total, offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monday) else { return total }
            return total + model.breakSeconds(on: date)
        }
    }

    private var monthBreakSeconds: TimeInterval {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: model.now)
        let components = calendar.dateComponents([.year, .month], from: today)
        guard let monthStart = calendar.date(from: components),
              let days = calendar.range(of: .day, in: .month, for: monthStart) else { return 0 }
        return days.reduce(0) { total, day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return total }
            return total + model.breakSeconds(on: date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard(title: "摸鱼统计开关", subtitle: "", icon: "timer") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("启用摸鱼统计")
                        Text("开启后可记录休息，并统计实际工作时间")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    HelpPopover(title: "摸鱼统计", message: "仅记录你主动开始和结束的休息，不会监控键盘、鼠标或屏幕。关闭后停止统计；已有记录会保留。")
                    Spacer()
                    Toggle("启用摸鱼统计", isOn: $model.settings.effectiveWorkTrackingEnabled)
                        .labelsHidden().toggleStyle(.switch)
                }
            }

            if model.settings.effectiveWorkTrackingEnabled {
                SettingsCard(title: "今日摸鱼概况", subtitle: "", icon: "chart.pie") {
                    HStack(alignment: .top, spacing: 10) {
                        statisticTile(
                            title: "实际工作",
                            value: formatDuration(model.todayEffectiveWorkSeconds),
                            detail: "已扣除符合规则的摸鱼时间",
                            symbol: "briefcase.fill",
                            tint: .accentColor
                        )
                        statisticTile(
                            title: "摸鱼时长",
                            value: formatDuration(model.todayBreakSeconds),
                            detail: "实际记录与估算合并",
                            symbol: "cup.and.saucer.fill",
                            tint: .orange
                        )
                    }
                    Divider()
                    HStack(spacing: 8) {
                        metricDetail(title: "实际记录", value: formatDuration(model.todayActualBreakSeconds), symbol: "record.circle")
                        Spacer(minLength: 4)
                        metricDetail(title: "系统估算", value: formatDuration(model.todayEstimatedBreakSeconds), symbol: "wand.and.stars")
                    }
                    Text("计算方式：按每种摸鱼类型分别比较实际记录和每日估算，取较大值，不重复相加。仅开启扣除的类型会计入。")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    HStack(spacing: 12) {
                        metricSummary(title: "本周摸鱼", value: formatDuration(weekBreakSeconds), symbol: "calendar")
                        Spacer()
                        metricSummary(title: "本月摸鱼", value: formatDuration(monthBreakSeconds), symbol: "calendar.badge.clock")
                    }
                    Divider()
                    HStack {
                        Label("实际工作时薪", systemImage: "yensign.circle")
                        HelpPopover(title: "实际工作时薪", message: "按当日预计工资 ÷（计划工作时长 − 已扣除的摸鱼时长）计算。仅用于工时分析，不改变工资发放或收入累计。")
                        Spacer()
                        Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(model.effectiveHourlyRate))
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                    }
                }
            }

            if model.settings.effectiveWorkTrackingEnabled {
                SettingsCard(title: "摸鱼扣除规则", subtitle: "", icon: "slider.horizontal.3") {
                    Text("开启的类型会从实际工作时间中扣除；关闭只停止扣除，不会删除记录。")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 9) {
                        deductionToggle("上厕所", icon: "toilet", isOn: $model.settings.deductRestroomBreaks)
                        deductionToggle("玩手机", icon: "iphone", isOn: $model.settings.deductPhoneBreaks)
                        deductionToggle("喝水 / 休息", icon: "cup.and.saucer", isOn: $model.settings.deductShortBreaks)
                        deductionToggle("吃饭", icon: "fork.knife", isOn: $model.settings.deductMealBreaks)
                        deductionToggle("其他", icon: "ellipsis.circle", isOn: $model.settings.deductOtherBreaks)
                    }
                    HStack(spacing: 5) {
                        HelpPopover(title: "摸鱼扣除规则", message: "摸鱼记录始终保留。只有开启对应类型的扣除开关，该类型才会从实际工作时间中扣除。启用午休时，午休已从计划工作时间中排除，吃饭默认不重复扣除；未启用午休时，可按实际情况开启吃饭扣除。")
                        Text("午休已单独计算，避免重复扣除")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: "每日摸鱼估算", subtitle: "", icon: "calendar.badge.clock") {
                    estimateRow("上厕所", value: $model.settings.estimatedRestroomBreakMinutes)
                    estimateRow("玩手机", value: $model.settings.estimatedPhoneBreakMinutes)
                    estimateRow("喝水 / 休息", value: $model.settings.estimatedShortBreakMinutes)
                    estimateRow("吃饭", value: $model.settings.estimatedMealBreakMinutes)
                    estimateRow("其他", value: $model.settings.estimatedOtherBreakMinutes)
                    Divider()
                    HStack {
                        Text("每日估算合计")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text("\(estimatedDailyMinutes) 分钟")
                            .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    }
                    HStack(spacing: 5) {
                        HelpPopover(title: "每日摸鱼估算", message: "实际记录与每日估算按类型分别取较大值，不会重复相加。只有对应类型开启工时扣除时，估算才会影响有效工时；设置为 0 分钟即可关闭该类型估算。估算仅用于工作日，并随计划工作时间逐步累计；午休和下班时间不会计入估算扣除。")
                        Text("估算与实际记录的计算方式")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }

                SettingsCard(title: "摸鱼记录", subtitle: "", icon: "list.bullet.rectangle") {
                    HStack {
                        Text("手动补录一段休息时间")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            showingManualEntry = true
                        } label: {
                            Label("手动添加", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if let active = model.activeBreak {
                        HStack {
                            Label(AppLocalization.string(active.type.title, language: model.settings.language) + " · " + AppLocalization.string("进行中", language: model.settings.language), systemImage: active.type.symbol)
                            Spacer()
                            Text(formatDuration(model.now.timeIntervalSince(active.startTime)))
                                .monospacedDigit()
                            Button("结束") { model.endBreak() }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                    if recentRecords.isEmpty && model.activeBreak == nil {
                        Text("今天还没有摸鱼记录。可在悬浮窗中点击「开始休息」记录一次。")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentRecords) { record in
                            HStack(spacing: 8) {
                                Image(systemName: record.type.symbol)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(AppLocalization.string(record.type.title, language: model.settings.language))
                                        .font(.system(size: 11, weight: .medium))
                                    Text("\(record.startTime.formatted(date: .abbreviated, time: .shortened)) – \((record.endTime ?? record.startTime).formatted(date: .abbreviated, time: .shortened))")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(formatDuration(record.duration))
                                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                                    Text(record.deductFromWork ? "已扣除" : "未扣除")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                }
                                Button(role: .destructive) {
                                    model.deleteBreak(record)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .help("删除这条记录")
                            }
                            .padding(.vertical, 4)
                            if record.id != recentRecords.last?.id { Divider() }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            ManualWorkBreakEntryView()
                .environmentObject(model)
        }
    }

    private var estimatedDailyMinutes: Int {
        WorkBreakType.allCases.reduce(0) { $0 + WorkBreakCalculator.configuredMinutes(for: $1, settings: model.settings) }
    }

    private func estimateRow(_ title: String, value: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11))
            Spacer()
            TextField("分钟", value: Binding(
                get: { min(240, max(0, value.wrappedValue)) },
                set: { value.wrappedValue = min(240, max(0, $0)) }
            ), format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 62)
            Text("分钟").font(.system(size: 10)).foregroundStyle(.secondary)
            Stepper("", value: value, in: 0...240, step: 5)
                .labelsHidden().controlSize(.small)
        }
    }

    private func statisticTile(title: String, value: String, detail: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.75)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }

    private func metricDetail(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
            }
        }
    }

    private func metricSummary(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
        }
    }

    private func deductionToggle(_ title: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 16)
            Text(title).font(.system(size: 11, weight: .medium)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 3)
            Toggle(title, isOn: isOn).labelsHidden().toggleStyle(.switch).controlSize(.small).fixedSize()
        }
        .padding(.horizontal, 9).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        let hours = value / 3600
        let minutes = (value % 3600) / 60
        let remaining = value % 60
        if hours > 0 { return String(format: "%d小时%02d分", hours, minutes) }
        if minutes > 0 { return String(format: "%d分%02d秒", minutes, remaining) }
        return "\(remaining)秒"
    }
}

private struct ManualWorkBreakEntryView: View {
    @EnvironmentObject private var model: SalaryClockModel
    @Environment(\.dismiss) private var dismiss
    @State private var type: WorkBreakType = .restroom
    @State private var startTime = Calendar.current.date(byAdding: .minute, value: -10, to: Date()) ?? Date()
    @State private var endTime = Date()
    @State private var errorMessage: String?

    private var hasOverlap: Bool {
        model.breakRecords.contains { record in
            let existingEnd = record.endTime ?? model.now
            return startTime < existingEnd && endTime > record.startTime
        } || (model.activeBreak.map { startTime < model.now && endTime > $0.startTime } ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("手动补录休息")
                .font(.system(size: 16, weight: .semibold))
            Text("选择休息类型和实际开始、结束时间，系统会自动计算时长并应用对应的工时扣除规则。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Form {
                Picker("休息类型", selection: $type) {
                    ForEach(WorkBreakType.allCases) { item in
                        Label(AppLocalization.string(item.title, language: model.settings.language), systemImage: item.symbol)
                            .tag(item)
                    }
                }
                DatePicker("开始时间", selection: $startTime, displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.field)
                DatePicker("结束时间", selection: $endTime, displayedComponents: [.date, .hourAndMinute]).datePickerStyle(.field)
            }
            if endTime > model.now {
                Text("手动补录的结束时间不能晚于当前时间。")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            } else if endTime <= startTime {
                Text("结束时间必须晚于开始时间。")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            } else if hasOverlap {
                Text("该时间段与已有摸鱼记录重叠，请调整时间，避免重复统计。")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存记录") {
                    if model.addBreak(type, start: startTime, end: endTime) {
                        dismiss()
                    } else {
                        errorMessage = "保存失败，请检查时间范围或是否与已有记录重叠。"
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(endTime > model.now || endTime <= startTime || hasOverlap)
            }
        }
        .padding(22)
        .frame(width: 430)
        .fixedSize(horizontal: false, vertical: true)
    }
}
