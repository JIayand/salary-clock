import SwiftUI

struct FloatingWidgetView: View {
    @EnvironmentObject private var model: SalaryClockModel
    @State private var isHovering = false
    @State private var isPinnedExpanded = false

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

    private var isCompactCollapsed: Bool {
        model.settings.compactMode && !isHovering && !isPinnedExpanded
    }

    var body: some View {
        let snapshot = model.snapshot
        Group {
            if isCompactCollapsed {
                compactContent(snapshot)
            } else {
                expandedContent(snapshot)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            guard model.settings.compactMode else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                isHovering = hovering
            }
        }
        .onChange(of: model.settings.compactMode) { enabled in
            if !enabled { isPinnedExpanded = false }
        }
        .frame(minWidth: isCompactCollapsed ? 190 : 310, idealWidth: isCompactCollapsed ? 210 : 340, maxWidth: isCompactCollapsed ? 230 : 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func compactContent(_ snapshot: SalarySnapshot) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(snapshot.isWorkingNow ? accent : foreground.opacity(0.35)).frame(width: 6, height: 6)
                        Text("今日已赚").font(.system(size: 10, weight: .medium)).foregroundStyle(foreground.opacity(0.65))
                    }
                    Text(primaryValue(snapshot))
                        .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
                        .tracking(-0.8).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7)
                        .contentTransition(numberTransition)
                        .animation(numberAnimation, value: snapshot.earned)
                        .animation(numberAnimation, value: snapshot.progress)
                }
                Spacer(minLength: 2)
                VStack(alignment: .trailing, spacing: 5) {
                    HStack(spacing: 5) {
                        lockButton
                        privacyButton
                        Button { SettingsWindowController.shared.show(model: model) } label: {
                            Image(systemName: "slider.horizontal.3").font(.system(size: 12, weight: .medium))
                                .foregroundStyle(foreground.opacity(0.72)).frame(width: 22, height: 22)
                        }.buttonStyle(.plain).help("显示与计算设置")
                    }
                    Text(String(format: "%.*f%%", model.settings.percentDecimals, snapshot.progress * 100))
                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.72))
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(foreground.opacity(0.12))
                    Capsule().fill(accent).frame(width: proxy.size.width * snapshot.progress)
                }
            }.frame(height: 3)
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(background.opacity(model.settings.windowOpacity), in: Capsule())
        .overlay(Capsule().stroke(foreground.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
        .contentShape(Capsule())
        .onTapGesture { isPinnedExpanded.toggle() }
        .help("点击固定展开 / 收起，或将鼠标移入查看详情")
    }

    private func expandedContent(_ snapshot: SalarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Circle().fill(snapshot.isWorkingNow ? accent : foreground.opacity(0.35)).frame(width: 7, height: 7)
                Text(statusText(snapshot)).font(.system(size: 11, weight: .medium)).foregroundStyle(foreground.opacity(0.74))
                Spacer(minLength: 4)
                Text(Date.now.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.4))
                lockButton
                privacyButton
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        model.settings.compactMode.toggle()
                        isPinnedExpanded = false
                        isHovering = false
                    }
                } label: {
                    Image(systemName: model.settings.compactMode ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.7)).frame(width: 22, height: 22)
                }.buttonStyle(.plain).help(model.settings.compactMode ? "关闭紧凑模式" : "启用紧凑模式")
                Button { SettingsWindowController.shared.show(model: model) } label: {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(foreground.opacity(0.7)).frame(width: 24, height: 24)
                }.buttonStyle(.plain).help("显示与计算设置")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(model.settings.mode == .money ? "今日已赚取（估算）" : "今日工作进度")
                    .font(.system(size: 11)).foregroundStyle(foreground.opacity(0.55))
                Text(primaryValue(snapshot))
                    .font(.system(size: model.settings.mode == .money ? 36 : 42, weight: .semibold, design: .rounded).monospacedDigit())
                    .tracking(-1.4).foregroundStyle(accent).contentTransition(numberTransition)
                    .minimumScaleFactor(0.62).lineLimit(1)
                    .animation(numberAnimation, value: snapshot.earned)
                    .animation(numberAnimation, value: snapshot.progress)
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
                        Text("今日进度 " + String(format: "%.*f%%", model.settings.percentDecimals, snapshot.progress * 100))
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
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.0).font(.system(size: 9, weight: .medium)).foregroundStyle(foreground.opacity(0.52))
                            Text(item.1).font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(foreground.opacity(0.92)).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(foreground.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            if !model.settings.familyMembers.isEmpty {
                let familySnapshots = model.settings.familyMembers.map { ($0, model.snapshot(for: $0)) }
                let familyTotal = familySnapshots.reduce(0.0) { $0 + $1.1.earned }
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill").font(.system(size: 10, weight: .semibold))
                            Text("家庭收入").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(foreground.opacity(0.72))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("合计今日").font(.system(size: 8)).foregroundStyle(foreground.opacity(0.42))
                            Text(model.settings.privacyMode ? "¥ ••••" : String(format: "¥ %.*f", model.settings.decimals, familyTotal))
                                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(accent)
                        }
                    }
                    ForEach(familySnapshots, id: \.0.id) { member, memberSnapshot in
                        HStack(spacing: 9) {
                            Text(String(member.name.prefix(1)).isEmpty ? "家" : String(member.name.prefix(1)))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(width: 27, height: 27)
                                .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name.isEmpty ? "未命名成员" : member.name)
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(foreground.opacity(0.9)).lineLimit(1)
                                Text("月薪 ¥\(Int(member.monthlySalary).formatted())")
                                    .font(.system(size: 8, weight: .medium, design: .rounded)).foregroundStyle(foreground.opacity(0.42))
                            }
                            Spacer(minLength: 4)
                            Text(model.settings.privacyMode ? "¥ ••••" : String(format: "¥ %.*f", model.settings.decimals, memberSnapshot.earned))
                                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(accent)
                        }
                        .padding(.horizontal, 9).padding(.vertical, 7)
                        .background(foreground.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(11)
                .background(foreground.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(foreground.opacity(0.07), lineWidth: 1))
                .padding(.top, 1)
            }
        }
        .padding(17)
        .background(background.opacity(model.settings.windowOpacity), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(foreground.opacity(0.09), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
        .foregroundStyle(foreground)
    }

    private var numberTransition: ContentTransition {
        model.settings.numberAnimation == .rolling ? .numericText() : .opacity
    }

    private var numberAnimation: Animation {
        model.settings.numberAnimation == .rolling
            ? .snappy(duration: 0.22)
            : .easeInOut(duration: 0.28)
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
        if model.settings.mode == .percent {
            return String(format: "%.*f%%", model.settings.percentDecimals, s.progress * 100)
        }
        return model.settings.privacyMode ? "¥ ••••" : String(format: "¥ %.*f", model.settings.decimals, s.earned)
    }
    private var lockButton: some View {
        Button { model.settings.windowLocked.toggle() } label: {
            Image(systemName: model.settings.windowLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.settings.windowLocked ? accent : foreground.opacity(0.72))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(model.settings.windowLocked ? "已锁定位置，点击解锁后可拖动" : "锁定当前位置，防止误拖动")
    }

    private var privacyButton: some View {
        Button { model.settings.privacyMode.toggle() } label: {
            Image(systemName: model.settings.privacyMode ? "eye.slash" : "eye")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(foreground.opacity(0.72)).frame(width: 22, height: 22)
        }.buttonStyle(.plain).help(model.settings.privacyMode ? "显示金额" : "隐藏金额（隐私模式）")
    }

    private func money(_ value: Double) -> String {
        model.settings.privacyMode ? "¥ ••••" : String(format: "¥ %.2f", value)
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
    }
}
