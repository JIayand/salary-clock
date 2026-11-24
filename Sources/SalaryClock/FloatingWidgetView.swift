import SwiftUI

struct FloatingWidgetView: View {
    @EnvironmentObject private var model: SalaryClockModel
    @State private var showSettings = false

    private var foreground: Color {
        switch model.settings.theme {
        case .midnight, .neon, .ocean, .sunset: return .white
        case .paper: return Color(red: 0.13, green: 0.16, blue: 0.19)
        case .graphite: return Color(red: 0.91, green: 0.92, blue: 0.94)
        }
    }
    private var background: Color {
        switch model.settings.theme {
        case .midnight: return Color(red: 0.075, green: 0.09, blue: 0.13)
        case .paper: return Color(red: 0.94, green: 0.93, blue: 0.89)
        case .neon: return Color(red: 0.025, green: 0.055, blue: 0.045)
        case .ocean: return Color(red: 0.055, green: 0.16, blue: 0.24)
        case .sunset: return Color(red: 0.25, green: 0.105, blue: 0.09)
        case .graphite: return Color(red: 0.12, green: 0.13, blue: 0.15)
        }
    }
    private var accent: Color {
        switch model.settings.theme {
        case .midnight: return Color(red: 0.35, green: 0.88, blue: 0.68)
        case .paper: return Color(red: 0.12, green: 0.48, blue: 0.37)
        case .neon: return Color(red: 0.55, green: 1, blue: 0.25)
        case .ocean: return Color(red: 0.38, green: 0.82, blue: 1)
        case .sunset: return Color(red: 1, green: 0.62, blue: 0.36)
        case .graphite: return Color(red: 0.76, green: 0.81, blue: 0.9)
        }
    }

    var body: some View {
        let snapshot = model.snapshot
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Circle().fill(snapshot.isWorkingNow ? accent : foreground.opacity(0.35)).frame(width: 7, height: 7)
                Text(statusText(snapshot)).font(.system(size: 11, weight: .medium)).foregroundStyle(foreground.opacity(0.74))
                Spacer(minLength: 4)
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.4))
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.7)).frame(width: 24, height: 24)
                }.buttonStyle(.plain).help("显示与计算设置")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(model.settings.mode == .money ? "今日已赚取（估算）" : "今日工作进度")
                    .font(.system(size: 11)).foregroundStyle(foreground.opacity(0.55))
                Text(primaryValue(snapshot))
                    .font(.system(size: model.settings.mode == .money ? 36 : 42, weight: .semibold, design: .rounded).monospacedDigit())
                    .tracking(-1.4).foregroundStyle(accent).contentTransition(.numericText())
                    .minimumScaleFactor(0.62).lineLimit(1)
                    .animation(.linear(duration: 0.09), value: snapshot.earned)
                    .animation(.linear(duration: 0.09), value: snapshot.progress)
            }

            if model.settings.showProgress || model.settings.showWorkDuration {
                VStack(spacing: 7) {
                    if model.settings.showProgress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(foreground.opacity(0.12))
                                Capsule().fill(LinearGradient(colors: [accent.opacity(0.65), accent], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: proxy.size.width * snapshot.progress)
                            }
                        }.frame(height: 5)
                        Text("今日进度 \(snapshot.progress * 100, specifier: "%.1f")%")
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(foreground.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if model.settings.showWorkDuration {
                        HStack {
                            Text("已工作 \(duration(snapshot.elapsedWorkSeconds))")
                            Spacer()
                            Text("剩余 \(duration(snapshot.remainingSeconds))")
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.55))
                    }
                }
            }

            let stats: [(String, String, Bool)] = [
                ("本周已赚", money(snapshot.weekEarned), model.settings.showWeekEarned),
                ("本月已赚", money(snapshot.monthEarned), model.settings.showMonthEarned),
                ("时薪", money(snapshot.hourlyRate), model.settings.showHourlyRate),
                ("日薪", money(snapshot.dailyRate), model.settings.showDailyRate)
            ].filter { $0.2 }
            if !stats.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 9) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0).font(.system(size: 9)).foregroundStyle(foreground.opacity(0.48))
                            Text(item.1).font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(foreground.opacity(0.88)).lineLimit(1).minimumScaleFactor(0.8)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(17)
        .background(background.opacity(model.settings.windowOpacity), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(foreground.opacity(0.09), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        .foregroundStyle(foreground)
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(model) }
        .frame(minWidth: 310, idealWidth: 340, maxWidth: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func statusText(_ snapshot: SalarySnapshot) -> String {
        if snapshot.isPublicHoliday { return "法定节假日 · 今天休息" }
        if snapshot.isMakeupWorkday && snapshot.isWorkingNow { return "调休补班 · 正在赚钱" }
        if snapshot.isMakeupWorkday { return "调休补班日" }
        if snapshot.isWorkingNow { return "正在为你赚钱" }
        if snapshot.isWorkday { return "当前非计薪时段" }
        return "今天不是工作日"
    }
    private func primaryValue(_ s: SalarySnapshot) -> String {
        model.settings.mode == .percent
            ? String(format: "%.*f%%", model.settings.decimals, s.progress * 100)
            : String(format: "¥ %.*f", model.settings.decimals, s.earned)
    }
    private func money(_ value: Double) -> String { String(format: "¥ %.2f", value) }
    private func duration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    }
}
