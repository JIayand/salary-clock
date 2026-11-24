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
        Form {
            Section("薪资") {
                HStack {
                    Text("月薪（元）")
                    Spacer()
                    TextField("10000", value: $model.settings.monthlySalary, format: .number.precision(.fractionLength(0...2)))
                        .multilineTextAlignment(.trailing).frame(width: 120)
                }
                Picker("显示模式", selection: $model.settings.mode) {
                    ForEach(DisplayMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("小数位数", selection: $model.settings.decimals) {
                    ForEach(2...6, id: \.self) { Text("\($0) 位").tag($0) }
                }
            }
            Section("工作制度") {
                Picker("预设制度", selection: schedulePreset) {
                    Text("双休").tag("双休")
                    Text("单休").tag("单休")
                    Text("自定义").tag("自定义")
                }
                HStack {
                    ForEach([(1,"日"),(2,"一"),(3,"二"),(4,"三"),(5,"四"),(6,"五"),(7,"六")], id: \.0) { day, label in
                        let selected = model.settings.workdays.contains(day)
                        Button(label) {
                            if selected { model.settings.workdays.remove(day) }
                            else { model.settings.workdays.insert(day) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selected ? .accentColor : .gray.opacity(0.25))
                    }
                }
                Text("单休默认周一至周六计薪；也可以点选星期自定义。官方节假日和补班安排优先于每周规则。")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("应用中国法定节假日及调休", isOn: $model.settings.useChinaHolidayCalendar)
            }
            Section("工作时间") {
                timeRow("上班时间", hour: $model.settings.startHour, minute: $model.settings.startMinute)
                timeRow("下班时间", hour: $model.settings.endHour, minute: $model.settings.endMinute)
            }
            Section("午休时间（不计薪）") {
                timeRow("午休开始", hour: $model.settings.lunchStartHour, minute: $model.settings.lunchStartMinute)
                timeRow("午休结束", hour: $model.settings.lunchEndHour, minute: $model.settings.lunchEndMinute)
            }
            Section("桌面显示内容") {
                Toggle("今日进度百分比和进度条", isOn: $model.settings.showProgress)
                Toggle("本周累计收入", isOn: $model.settings.showWeekEarned)
                Toggle("本月累计收入", isOn: $model.settings.showMonthEarned)
                Toggle("时薪", isOn: $model.settings.showHourlyRate)
                Toggle("日薪", isOn: $model.settings.showDailyRate)
                Toggle("已工作 / 剩余时间", isOn: $model.settings.showWorkDuration)
                Text("关闭不需要的指标，挂件会自动收紧布局，适合只显示今日收入的简洁模式。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("外观") {
                Picker("主题", selection: $model.settings.theme) {
                    ForEach(WidgetTheme.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("背景透明度")
                        Spacer()
                        Text("\(Int(model.settings.windowOpacity * 100))%")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $model.settings.windowOpacity, in: 0.55...1.0, step: 0.05)
                }
            }
            Section {
                Text("日薪 = 月薪 ÷ 当月计薪工作日；时薪 = 日薪 ÷ 当日有效工时。本周和本月累计按已完成工作日加上今天实时进度估算。午休不计薪。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("完成") { dismiss() }.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .formStyle(.grouped)
        .frame(width: 430, height: 780)
    }

    @ViewBuilder
    private func timeRow(_ title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker("小时", selection: hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden().frame(width: 65)
            Text(":")
            Picker("分钟", selection: minute) {
                ForEach([0, 5, 10, 15, 20, 30, 40, 45, 50, 55], id: \.self) {
                    Text(String(format: "%02d", $0)).tag($0)
                }
            }.labelsHidden().frame(width: 65)
        }
    }
}
