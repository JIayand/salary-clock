import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: SalaryClockModel
    @Environment(\.dismiss) private var dismiss

    private var schedulePreset: Binding<String> {
        Binding(
            get: {
                if model.settings.workdays == Set([2, 3, 4, 5, 6]) { return "双休" }
                if model.settings.workdays == Set([2, 3, 4, 5, 6, 7]) { return "单休" }
                return "自定义"
            },
            set: { value in
                if value == "双休" { model.settings.workdays = Set([2, 3, 4, 5, 6]) }
                if value == "单休" { model.settings.workdays = Set([2, 3, 4, 5, 6, 7]) }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    salarySection
                    taxSection
                    scheduleSection
                    timeSection
                    displaySection
                    appearanceSection
                    calculationNote
                }
                .padding(18)
            }
            .scrollIndicators(.automatic)
            footer
        }
        .frame(width: 470, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("薪资时钟设置").font(.system(size: 15, weight: .semibold))
                Text("调整薪资计算、显示内容和外观").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Button { SettingsWindowController.shared.close() } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 26, height: 26)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("关闭设置")
        }
        .padding(.horizontal, 18).padding(.vertical, 13)
        .background(.bar)
    }

    private var salarySection: some View {
        SettingsCard(title: "薪资计算", subtitle: "设置月薪和挂件主显示方式", icon: "yensign.circle") {
            HStack {
                Text("月薪（元）")
                Spacer()
                TextField("请输入月薪", value: $model.settings.monthlySalary, format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 142)
            }
            Divider()
            HStack {
                Text("主显示内容")
                Spacer()
                Picker("主显示内容", selection: $model.settings.mode) {
                    ForEach(DisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 150)
            }
            HStack {
                Label("金额小数位", systemImage: "number")
                Spacer()
                decimalPicker(selection: $model.settings.decimals, range: 0...6)
            }
            HStack {
                Label("百分比小数位", systemImage: "percent")
                Spacer()
                decimalPicker(selection: $model.settings.percentDecimals, range: 0...4)
            }
            Text("金额精度和百分比精度分别设置，互不影响。")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var taxSection: some View {
        SettingsCard(title: "税后工资", subtitle: "按中国居民综合所得年度税率估算月度个税", icon: "receipt") {
            Toggle("使用税后工资计算收入", isOn: $model.settings.useAfterTaxSalary)
                .toggleStyle(.switch)
            HStack {
                Text("月度社保 / 公积金个人缴纳")
                Spacer()
                TextField("0", value: $model.settings.monthlySocialInsurance, format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 112)
            }
            HStack {
                Text("月度专项附加扣除")
                Spacer()
                TextField("0", value: $model.settings.monthlySpecialDeductions, format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 112)
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("预计税后月薪").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("含社保、公积金个人缴纳扣除").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                Spacer()
                Text("¥ " + String(format: "%.2f", model.snapshot.netMonthlySalary))
                    .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
            }
            HStack {
                Text("预计月度个税")
                Spacer()
                Text("¥ " + String(format: "%.2f", model.snapshot.tax))
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
            }
            helpText("估算采用年度综合所得税率表，按全年 12 个月工资相同计算。社保 / 公积金和专项附加扣除需自行填写；未录入的年终奖、其他收入、专项扣除及累计预扣差异不会自动纳入。结果仅供参考，不等同于工资单或个税申报金额。")
        }
    }

    private var scheduleSection: some View {
        SettingsCard(title: "工作制度", subtitle: "决定哪些日期参与薪资计算", icon: "calendar") {
            HStack {
                Text("每周工作制度")
                Spacer()
                Picker("每周工作制度", selection: schedulePreset) {
                    Text("双休").tag("双休")
                    Text("单休").tag("单休")
                    Text("自定义").tag("自定义")
                }
                .labelsHidden().frame(width: 112)
            }
            HStack(spacing: 6) {
                ForEach([(1,"日"),(2,"一"),(3,"二"),(4,"三"),(5,"四"),(6,"五"),(7,"六")], id: \.0) { day, label in
                    let selected = model.settings.workdays.contains(day)
                    Button {
                        if selected { model.settings.workdays.remove(day) }
                        else { model.settings.workdays.insert(day) }
                    } label: {
                        Text(label).font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 29)
                            .foregroundStyle(selected ? Color.white : Color.secondary)
                            .background(selected ? Color.accentColor : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            helpText("官方节假日和补班安排优先于每周规则；关闭节假日日历后，仅按上方星期设置计算。")
            Toggle(isOn: $model.settings.useChinaHolidayCalendar) {
                Label("中国法定节假日及调休", systemImage: "calendar.badge.clock")
            }
            .toggleStyle(.switch)
        }
    }

    private var timeSection: some View {
        SettingsCard(title: "工作时间", subtitle: "午休时段会从有效计薪时间中扣除", icon: "clock") {
            timeRow("上班", hour: $model.settings.startHour, minute: $model.settings.startMinute)
            Divider()
            timeRow("下班", hour: $model.settings.endHour, minute: $model.settings.endMinute)
            Divider()
            timeRow("午休开始", hour: $model.settings.lunchStartHour, minute: $model.settings.lunchStartMinute)
            Divider()
            timeRow("午休结束", hour: $model.settings.lunchEndHour, minute: $model.settings.lunchEndMinute)
        }
    }

    private var displaySection: some View {
        SettingsCard(title: "桌面显示", subtitle: "关闭不需要的项目，让挂件保持简洁", icon: "rectangle.on.rectangle") {
            VStack(spacing: 0) {
                ToggleRow(title: "紧凑悬浮模式", subtitle: "默认收起，鼠标移入展开详情", isOn: $model.settings.compactMode) {
                    HelpPopover(title: "紧凑悬浮模式", message: "开启后，挂件平时只显示今日收入和进度条。鼠标移入挂件会自动展开全部统计，移出后收起。点击挂件可以固定展开；展开状态下点击收起图标可恢复自动收起。")
                }
                Divider().padding(.leading, 2)
                HStack {
                    Text("数字变化动画")
                    Spacer()
                    Picker("数字变化动画", selection: $model.settings.numberAnimation) {
                        ForEach(NumberAnimationStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden().frame(width: 125)
                }
                .padding(.top, 10)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    DisplayToggle(title: "今日进度", icon: "chart.bar", isOn: $model.settings.showProgress)
                    DisplayToggle(title: "已工作 / 剩余", icon: "hourglass", isOn: $model.settings.showWorkDuration)
                    DisplayToggle(title: "本周累计", icon: "calendar.day.timeline.left", isOn: $model.settings.showWeekEarned)
                    DisplayToggle(title: "本月累计", icon: "calendar", isOn: $model.settings.showMonthEarned)
                    DisplayToggle(title: "时薪", icon: "clock", isOn: $model.settings.showHourlyRate)
                    DisplayToggle(title: "日薪", icon: "sun.max", isOn: $model.settings.showDailyRate)
                }
                .padding(.top, 10)
            }
        }
    }

    private var appearanceSection: some View {
        SettingsCard(title: "外观", subtitle: "调整主题和背景透明度", icon: "paintpalette") {
            HStack {
                Text("主题")
                Spacer()
                Picker("主题", selection: $model.settings.theme) {
                    ForEach(WidgetTheme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().frame(width: 145)
            }
            HStack(spacing: 10) {
                Text("背景透明度")
                Slider(value: $model.settings.windowOpacity, in: 0.55...1.0, step: 0.05)
                Text("\(Int(model.settings.windowOpacity * 100))%")
                    .font(.system(size: 11, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary).frame(width: 38, alignment: .trailing)
            }
        }
    }

    private var calculationNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").foregroundStyle(.secondary)
            Text("日薪 = 月薪 ÷ 当月计薪工作日；时薪 = 日薪 ÷ 每日有效工时。本周和本月累计包含已完成工作日及今天的实时进度。午休不计薪。")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 3)
    }

    private var footer: some View {
        HStack {
            Text("设置会自动保存").font(.system(size: 10)).foregroundStyle(.tertiary)
            Spacer()
            Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent).controlSize(.regular)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.bar)
    }

    private func decimalPicker(selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Picker("小数位", selection: selection) {
            ForEach(range, id: \.self) { Text("\($0) 位").tag($0) }
        }
        .labelsHidden().frame(width: 95)
    }

    @ViewBuilder
    private func timeRow(_ title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Spacer()
            Picker("小时", selection: hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden().frame(width: 76)
            Text(":").foregroundStyle(.secondary)
            Picker("分钟", selection: minute) {
                ForEach([0, 5, 10, 15, 20, 30, 40, 45, 50, 55], id: \.self) {
                    Text(String(format: "%02d", $0)).tag($0)
                }
            }.labelsHidden().frame(width: 76)
        }
    }

    private func helpText(_ value: String) -> some View {
        Text(value).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(.tint).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            content
        }
        .padding(13)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.055), lineWidth: 1))
    }
}

private struct ToggleRow<Help: View>: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @ViewBuilder let help: Help

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            help
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

private struct DisplayToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon).font(.system(size: 11))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct HelpPopover: View {
    let title: String
    let message: String
    @State private var isPresented = false

    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(size: 12, weight: .semibold))
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(width: 260, alignment: .leading)
        }
        .help("查看说明")
    }
}
