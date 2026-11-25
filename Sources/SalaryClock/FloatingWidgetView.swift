import SwiftUI
import AppKit
import QuartzCore

struct FloatingWidgetView: View {
    @EnvironmentObject private var model: SalaryClockModel
    @State private var isHovering = false
    @State private var isPointerInside = false
    @State private var controlsVisible = true
    @State private var isPinnedExpanded = false
    @State private var expandsUpward = false
    @State private var expandedMemberIDs: Set<UUID> = []
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var resizeWorkItem: DispatchWorkItem?
    @State private var resizeAnchorFrame: NSRect?

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
        // Track pointer entry at the AppKit view level. SwiftUI onHover can miss
        // events on a borderless, non-activating NSPanel on some macOS versions.
        .overlay {
            GeometryReader { geometry in
                WidgetHoverTracker { hovering in
                    updatePointerHover(hovering)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .allowsHitTesting(false)
            }
        }
        // Explicit native drag handle in the non-interactive left side of the
        // top header. The right side remains available for lock/privacy/settings.
        .overlay(alignment: .topLeading) {
            WidgetDragHandle(isLocked: model.settings.windowLocked)
                .frame(width: max(80, (isCompactCollapsed ? 210 : 340) * 0.62), height: 26)
                .padding(.leading, 8)
                .padding(.top, 3)
        }
        .onReceive(NotificationCenter.default.publisher(for: .salaryClockPointerAfterDrag)) { notification in
            guard let inside = notification.userInfo?["inside"] as? Bool else { return }
            updatePointerHover(inside)
        }
        .simultaneousGesture(TapGesture().onEnded {
            revealControls()
        })
        .onAppear {
            scheduleControlsHide()
        }
        .onDisappear {
            hideControlsWorkItem?.cancel()
            resizeWorkItem?.cancel()
        }
        .onChange(of: model.settings.windowLocked) { _ in
            NotificationCenter.default.post(name: .salaryClockWindowLockChanged, object: nil)
        }
        .onChange(of: model.settings.compactMode) { enabled in
            if !enabled { isPinnedExpanded = false }
            resizeWidgetWindow()
        }
        .onChange(of: model.settings.effectiveWorkTrackingEnabled) { _ in
            resizeWidgetWindow()
        }
        .frame(minWidth: isCompactCollapsed ? 190 : 310, idealWidth: isCompactCollapsed ? 210 : 340, maxWidth: isCompactCollapsed ? 230 : 380)
        .fixedSize(horizontal: false, vertical: true)
        .environment(\.locale, model.settings.language.locale)
    }

    private func compactContent(_ snapshot: SalarySnapshot) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Circle().fill(snapshot.isWorkingNow ? accent : foreground.opacity(0.35)).frame(width: 6, height: 6)
                        Text("今日已赚").font(.system(size: 10, weight: .medium)).foregroundStyle(foreground.opacity(0.65))
                    }
                    Text(primaryValue(snapshot))
                        .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
                        .tracking(-0.8).foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.48)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(numberTransition)
                        .animation(numberAnimation, value: snapshot.earned)
                        .animation(numberAnimation, value: snapshot.progress)
                }
                Spacer(minLength: 2)
                VStack(alignment: .trailing, spacing: 5) {
                    if controlsVisible {
                        HStack(spacing: 5) {
                            lockButton
                            privacyButton
                            settingsButton(size: 12)
                        }
                        .transition(.opacity)
                    }
                    if model.settings.mode == .money {
                        Text(NumericFormatting.number(snapshot.progress * 100, fractionDigits: model.settings.percentDecimals) + "%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(foreground.opacity(0.72))
                    } else {
                        Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(snapshot.earned, fractionDigits: model.settings.decimals))
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(foreground.opacity(0.65))
                    }
                }
            }
            if model.settings.mode == .money {
                SalaryProgressBar(progress: snapshot.progress, style: model.settings.progressBarStyle,
                                  trackColor: foreground.opacity(0.12), fillColor: accent, height: 3)
            }
            if snapshot.isOvertime {
                overtimeStatusLine(snapshot)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(background.opacity(model.settings.windowOpacity), in: Capsule())
        .overlay(Capsule().stroke(foreground.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 14, y: 5)
        .contentShape(Capsule())
        .onTapGesture {
            isPinnedExpanded.toggle()
            resizeWidgetWindow()
        }
        .help(AppLocalization.string("点击固定展开 / 收起，或将鼠标移入查看详情", language: model.settings.language))
    }

    private func expandedContent(_ snapshot: SalarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 7) {
                Circle().fill(snapshot.isWorkingNow ? accent : foreground.opacity(0.35)).frame(width: 7, height: 7)
                Text(statusText(snapshot)).font(.system(size: 11, weight: .medium)).foregroundStyle(foreground.opacity(0.74))
                Spacer(minLength: 4)
                Text(Date.now.formatted(.dateTime.locale(.autoupdatingCurrent).month(.abbreviated).day()))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(foreground.opacity(0.4))
                if controlsVisible {
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
                    }.buttonStyle(.plain).help(AppLocalization.string(model.settings.compactMode ? "关闭紧凑模式" : "启用紧凑模式", language: model.settings.language))
                    settingsButton(size: 13)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(model.settings.mode == .money ? "今日已赚" : "今日工作进度")
                    .font(.system(size: 11)).foregroundStyle(foreground.opacity(0.55))
                Text(primaryValue(snapshot))
                    .font(.system(size: model.settings.mode == .money ? 36 : 42, weight: .semibold, design: .rounded).monospacedDigit())
                    .tracking(-1.4).foregroundStyle(accent).contentTransition(numberTransition)
                    .minimumScaleFactor(0.62).lineLimit(1)
                    .animation(numberAnimation, value: snapshot.earned)
                    .animation(numberAnimation, value: snapshot.progress)
                if model.settings.mode == .percent {
                    Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(snapshot.earned, fractionDigits: model.settings.decimals))
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.68))
                }
                if snapshot.isOvertime {
                    overtimeStatusLine(snapshot)
                    Button("结束加班") { model.endOvertime() }
                        .buttonStyle(.bordered).controlSize(.small)
                } else if model.canChooseAfterWork {
                    HStack(spacing: 8) {
                        Button("下班") { model.finishWorkday() }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("继续加班") { model.startOvertime() }
                            .buttonStyle(.borderedProminent).controlSize(.small)
                    }
                } else if snapshot.isWorkday && model.workdayClosedDateKey == ChinaWorkCalendar.dateKey(model.now, calendar: .current) {
                    Text("今日已下班").font(.system(size: 10, weight: .medium)).foregroundStyle(foreground.opacity(0.55))
                }
            }

            if (model.settings.showProgress && model.settings.mode == .money) || model.settings.showWorkDuration {
                VStack(spacing: 7) {
                    if model.settings.showProgress && model.settings.mode == .money {
                        SalaryProgressBar(progress: snapshot.progress, style: model.settings.progressBarStyle,
                                          trackColor: foreground.opacity(0.12), fillColor: accent, height: 5)
                        Text(AppLocalization.string("今日进度", language: model.settings.language) + " " + NumericFormatting.number(snapshot.progress * 100, fractionDigits: model.settings.percentDecimals) + "%")
                            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(foreground.opacity(0.55))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if model.settings.showWorkDuration && !snapshot.isOvertime {
                        HStack(spacing: 6) {
                            if model.settings.hourglassAnimationEnabled {
                                TimelineView(.animation(minimumInterval: 0.8, paused: false)) { context in
                                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4)
                                    Image(systemName: "hourglass")
                                        .font(.system(size: 10, weight: .medium))
                                        .rotationEffect(.degrees(phase < 1.2 ? 0 : 180))
                                        .foregroundStyle(accent)
                                }
                            }
                            Text(AppLocalization.string("已工作", language: model.settings.language) + " " + duration(snapshot.elapsedWorkSeconds))
                            Spacer()
                            Text(AppLocalization.string("剩余", language: model.settings.language) + " " + duration(snapshot.remainingSeconds))
                        }
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.55))
                    }
                }
            }

            if model.settings.effectiveWorkTrackingEnabled {
                effectiveWorkPanel
            }

            let stats: [(String, String, Bool)] = [
                ("本周已赚", money(snapshot.weekEarned), model.settings.showWeekEarned),
                ("本月已赚", money(snapshot.monthEarned), model.settings.showMonthEarned),
                ("时薪", money(snapshot.hourlyRate), model.settings.showHourlyRate),
                ("日薪", money(snapshot.dailyRate), model.settings.showDailyRate),
                ("秒薪", money(snapshot.secondRate, decimals: model.settings.secondRateDecimals), model.settings.showSecondRate),
                ("年薪", money(snapshot.annualSalary), model.settings.showAnnualSalary)
            ].filter { $0.2 }
            if !stats.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 9) {
                    ForEach(Array(stats.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(LocalizedStringKey(item.0)).font(.system(size: 9, weight: .medium)).foregroundStyle(foreground.opacity(0.52))
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
                let familyTotal = model.snapshot.earned + familySnapshots.reduce(0.0) { $0 + $1.1.earned }
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
                            Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(familyTotal, fractionDigits: model.settings.decimals))
                                .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(accent)
                        }
                    }
                    HStack(spacing: 9) {
                        Text("我")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 27, height: 27)
                            .background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("本人").font(.system(size: 10, weight: .semibold)).foregroundStyle(foreground.opacity(0.9))
                            let selfSalaryLabel = AppLocalization.string("月薪", language: model.settings.language)
                            Text("\(selfSalaryLabel) ¥\(NumericFormatting.integer(Int(model.settings.monthlySalary)))")
                                .font(.system(size: 8, weight: .medium, design: .rounded)).foregroundStyle(foreground.opacity(0.42))
                        }
                        Spacer(minLength: 4)
                        Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(model.snapshot.earned, fractionDigits: model.settings.decimals))
                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(accent)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .background(foreground.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    ForEach(familySnapshots, id: \.0.id) { member, memberSnapshot in
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                if resizeAnchorFrame == nil {
                                    resizeAnchorFrame = WidgetWindowActions.widgetWindow?.frame
                                }
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    if expandedMemberIDs.contains(member.id) { expandedMemberIDs.remove(member.id) }
                                    else { expandedMemberIDs.insert(member.id) }
                                }
                                resizeWidgetWindow()
                            } label: {
                                HStack(spacing: 9) {
                                    Text(String(member.name.prefix(1)).isEmpty ? AppLocalization.string("家", language: model.settings.language) : String(member.name.prefix(1)))
                                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(accent)
                                        .frame(width: 27, height: 27).background(accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name.isEmpty ? AppLocalization.string("未命名成员", language: model.settings.language) : member.name)
                                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(foreground.opacity(0.9)).lineLimit(1)
                                        let salaryLabel = AppLocalization.string("月薪", language: model.settings.language)
                                        Text("\(salaryLabel) ¥\(NumericFormatting.integer(Int(member.monthlySalary)))")
                                            .font(.system(size: 8, weight: .medium, design: .rounded)).foregroundStyle(foreground.opacity(0.42))
                                    }
                                    Spacer(minLength: 4)
                                    Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(memberSnapshot.earned, fractionDigits: model.settings.decimals))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(accent)
                                    Image(systemName: expandedMemberIDs.contains(member.id) ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(foreground.opacity(0.42))
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if expandedMemberIDs.contains(member.id) {
                                memberDetail(memberSnapshot)
                            }
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

    private var effectiveWorkPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: model.activeBreak == nil ? "timer" : "pause.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(model.activeBreak == nil ? accent : Color.orange)
                if let active = model.activeBreak {
                    Text(AppLocalization.string(active.type.title, language: model.settings.language) + "中")
                        .font(.system(size: 10, weight: .semibold))
                    Text(duration(model.now.timeIntervalSince(active.startTime)))
                        .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(foreground.opacity(0.7))
                    Spacer()
                    Button("结束休息") { model.endBreak() }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .controlSize(.small)
                } else {
                    Text("有效工时统计")
                        .font(.system(size: 10, weight: .semibold))
                    Spacer()
                    Menu {
                        ForEach(WorkBreakType.allCases) { type in
                            Button {
                                model.startBreak(type)
                            } label: {
                                Label(AppLocalization.string(type.title, language: model.settings.language), systemImage: type.symbol)
                            }
                        }
                    } label: {
                        Label("开始休息", systemImage: "pause.circle")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            HStack(spacing: 0) {
                metric("有效工作", duration(model.todayEffectiveWorkSeconds))
                Spacer(minLength: 5)
                metric("今日休息", duration(model.todayBreakSeconds))
                Spacer(minLength: 5)
                metric("折算时薪", model.settings.privacyMode ? "¥ ••••" : money(model.effectiveHourlyRate))
            }
        }
        .padding(10)
        .background(foreground.opacity(0.055), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(foreground.opacity(0.07), lineWidth: 1))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 8, weight: .medium)).foregroundStyle(foreground.opacity(0.5))
            Text(value).font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(foreground.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    @ViewBuilder
    private func memberDetail(_ snapshot: SalarySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(model.settings.mode == .percent
                 ? NumericFormatting.number(snapshot.progress * 100, fractionDigits: model.settings.percentDecimals) + "%"
                 : (model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(snapshot.earned, fractionDigits: model.settings.decimals)))
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(accent)
            if model.settings.mode == .percent {
                Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(snapshot.earned, fractionDigits: model.settings.decimals))
                    .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(foreground.opacity(0.65))
            } else if model.settings.showProgress {
                SalaryProgressBar(progress: snapshot.progress, style: model.settings.progressBarStyle, trackColor: foreground.opacity(0.12), fillColor: accent, height: 4)
            }
            if model.settings.showWorkDuration {
                HStack {
                    Text(AppLocalization.string("已工作", language: model.settings.language) + " " + duration(snapshot.elapsedWorkSeconds))
                    Spacer()
                    Text(AppLocalization.string("剩余", language: model.settings.language) + " " + duration(snapshot.remainingSeconds))
                }.font(.system(size: 9, weight: .medium, design: .rounded).monospacedDigit()).foregroundStyle(foreground.opacity(0.62))
            }
            let details: [(String, Double, Bool, Int)] = [
                ("本周已赚", snapshot.weekEarned, model.settings.showWeekEarned, model.settings.decimals),
                ("本月已赚", snapshot.monthEarned, model.settings.showMonthEarned, model.settings.decimals),
                ("时薪", snapshot.hourlyRate, model.settings.showHourlyRate, model.settings.decimals),
                ("日薪", snapshot.dailyRate, model.settings.showDailyRate, model.settings.decimals),
                ("秒薪", snapshot.secondRate, model.settings.showSecondRate, model.settings.secondRateDecimals),
                ("年薪", snapshot.annualSalary, model.settings.showAnnualSalary, model.settings.decimals)
            ].filter { $0.2 }
            if !details.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 6) {
                    ForEach(Array(details.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LocalizedStringKey(item.0)).font(.system(size: 8)).foregroundStyle(foreground.opacity(0.5))
                            Text(model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(item.1, fractionDigits: item.3))
                                .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(foreground.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.6)
                        }
                    }
                }
            }
        }
        .padding(.leading, 36)
    }

    private func resizeWidgetWindow() {
        // Coalesce rapid hover/click/layout changes into one frame update.
        // Repeated delayed measurements plus animated NSWindow resizing caused
        // visible flicker while entering the widget and expanding family rows.
        resizeWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            guard let window = WidgetWindowActions.widgetWindow,
                  let contentView = window.contentViewController?.view else { return }
            if (window as? SalaryClockPanel)?.isPointerInteractionActive == true { return }
            contentView.layoutSubtreeIfNeeded()
            let fitting = contentView.fittingSize
            let oldFrame = window.frame
            let anchorFrame = resizeAnchorFrame ?? oldFrame
            let screenFrame = (window.screen ?? NSScreen.main)?.visibleFrame ?? oldFrame
            let targetWidth = min(isCompactCollapsed ? 210 : 340, screenFrame.width)
            let desiredHeight = max(isCompactCollapsed ? 54 : 180, fitting.height)
            let targetHeight = min(desiredHeight, screenFrame.height)
            // Keep the original edge fixed across hover expansion and any
            // subsequent family-detail height changes. Never derive the anchor
            // from an in-flight animated frame.
            let targetY = expandsUpward ? anchorFrame.minY : anchorFrame.maxY - targetHeight
            let safeY = min(max(targetY, screenFrame.minY), screenFrame.maxY - targetHeight)
            let safeX = min(max(oldFrame.minX, screenFrame.minX), screenFrame.maxX - targetWidth)
            let newFrame = NSRect(x: safeX, y: safeY, width: targetWidth, height: targetHeight)
            window.minSize = NSSize(width: 190, height: 48)
            window.contentMinSize = NSSize(width: 190, height: 48)
            // Animate only the native window frame. SwiftUI structural/layout
            // animations remain disabled for this transition, avoiding two
            // competing animation systems while retaining a smooth expansion.
            if abs(oldFrame.height - newFrame.height) > 1 || abs(oldFrame.width - newFrame.width) > 1 || abs(oldFrame.origin.y - newFrame.origin.y) > 1 {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.26
                    context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 0.75, 0.25, 1.0)
                    window.animator().setFrame(newFrame, display: true)
                }
            }
        }
        resizeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private var numberTransition: ContentTransition {
        model.settings.numberAnimation == .rolling ? .numericText() : .opacity
    }

    private var numberAnimation: Animation {
        model.settings.numberAnimation == .rolling
            ? .snappy(duration: 0.18, extraBounce: 0.02)
            : .easeInOut(duration: 0.20)
    }

    private func statusText(_ snapshot: SalarySnapshot) -> String {
        if snapshot.isPublicHoliday { return AppLocalization.string("法定节假日 · 今天休息", language: model.settings.language) }
        if snapshot.isMakeupWorkday && snapshot.isWorkingNow { return AppLocalization.string("调休补班 · 工作中", language: model.settings.language) }
        if snapshot.isMakeupWorkday { return AppLocalization.string("调休补班日", language: model.settings.language) }
        if snapshot.isWorkingNow { return AppLocalization.string("工作中", language: model.settings.language) }
        if snapshot.isWorkday { return AppLocalization.string("当前非计薪时段", language: model.settings.language) }
        return AppLocalization.string("今天不是工作日", language: model.settings.language)
    }
    private func overtimeStatusLine(_ snapshot: SalarySnapshot) -> some View {
        HStack(spacing: 5) {
            Text("已加班")
            Text(overtimeDuration(snapshot.overtimeSeconds))
                .monospacedDigit()
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 1.0, green: 0.29, blue: 0.31))
    }

    private func overtimeDuration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%02d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
    }

    private func primaryValue(_ s: SalarySnapshot) -> String {
        if model.settings.mode == .percent {
            return NumericFormatting.number(s.progress * 100, fractionDigits: model.settings.percentDecimals) + "%"
        }
        return model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(s.earned, fractionDigits: model.settings.decimals)
    }
    private func updatePointerHover(_ hovering: Bool) {
        // Tracking areas can emit synthetic exit/enter events while the panel
        // changes size. Resolve hover from the panel's current screen frame so
        // a discarded exit event cannot leave compact mode stuck expanded.
        // Otherwise compact mode can collapse the content under the pointer,
        // making the panel appear to disappear during the drag.
        if (WidgetWindowActions.widgetWindow as? SalaryClockPanel)?.isPointerInteractionActive == true {
            return
        }
        let actualHover = WidgetWindowActions.widgetWindow.map { $0.frame.contains(NSEvent.mouseLocation) } ?? hovering
        guard isPointerInside != actualHover else { return }
        isPointerInside = actualHover
        if actualHover {
            revealControls()
        } else {
            scheduleControlsHide()
        }

        guard model.settings.compactMode, isHovering != actualHover else { return }
        if let window = WidgetWindowActions.widgetWindow {
            resizeAnchorFrame = window.frame
        }
        if actualHover, let window = WidgetWindowActions.widgetWindow {
            let screen = window.screen ?? NSScreen.screens.first
            if let visibleFrame = screen?.visibleFrame {
                expandsUpward = window.frame.midY < visibleFrame.midY
            }
        }
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            isHovering = actualHover
        }
        resizeWidgetWindow()
    }

    private func revealControls() {
        hideControlsWorkItem?.cancel()
        if !controlsVisible {
            withAnimation(.easeOut(duration: 0.13)) {
                controlsVisible = true
            }
        }
        if !isPointerInside {
            scheduleControlsHide()
        }
    }

    private func scheduleControlsHide() {
        hideControlsWorkItem?.cancel()
        guard !isPointerInside else { return }
        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.16)) {
                controlsVisible = false
            }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func settingsButton(size: CGFloat) -> some View {
        Button {
            SettingsWindowController.shared.show(model: model)
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(foreground.opacity(0.72))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(AppLocalization.string("显示与计算设置", language: model.settings.language))
    }

    private var lockButton: some View {
        Button {
            model.settings.windowLocked.toggle()
            NotificationCenter.default.post(name: .salaryClockWindowLockChanged, object: nil)
        } label: {
            Image(systemName: model.settings.windowLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(model.settings.windowLocked ? accent : foreground.opacity(0.72))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(AppLocalization.string(model.settings.windowLocked ? "已锁定位置，点击解锁后可拖动" : "锁定当前位置，防止误拖动", language: model.settings.language))
    }

    private var privacyButton: some View {
        Button { model.settings.privacyMode.toggle() } label: {
            Image(systemName: model.settings.privacyMode ? "eye.slash" : "eye")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(foreground.opacity(0.72)).frame(width: 22, height: 22)
        }.buttonStyle(.plain).help(AppLocalization.string(model.settings.privacyMode ? "显示金额" : "隐藏金额（隐私模式）", language: model.settings.language))
    }

    private func money(_ value: Double, decimals: Int? = nil) -> String {
        model.settings.privacyMode ? "¥ ••••" : NumericFormatting.currency(value, fractionDigits: decimals ?? model.settings.decimals)
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let value = Int(max(0, seconds))
        if model.settings.durationDisplay == .hoursMinutes {
            return String(format: "%02d:%02d", value / 3600, (value % 3600) / 60)
        }
        return String(format: "%02d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
    }
}


private struct WidgetDragHandle: NSViewRepresentable {
    let isLocked: Bool

    func makeNSView(context: Context) -> WidgetDragHandleView {
        let view = WidgetDragHandleView()
        view.isLocked = isLocked
        return view
    }

    func updateNSView(_ nsView: WidgetDragHandleView, context: Context) {
        nsView.isLocked = isLocked
    }
}

private final class WidgetDragHandleView: NSView {
    var isLocked = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        isLocked ? nil : super.hitTest(point)
    }

    override func mouseDown(with event: NSEvent) {
        guard !isLocked, let window else { return }
        window.performDrag(with: event)
        WidgetWindowActions.savePosition(of: window)
    }
}

private struct WidgetHoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> HoverTrackingNSView {
        let view = HoverTrackingNSView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ nsView: HoverTrackingNSView, context: Context) {
        nsView.onChange = onChange
    }
}

private final class HoverTrackingNSView: NSView {
    var onChange: ((Bool) -> Void)?
    private var trackingArea: NSTrackingArea?
    private var hoverPollTimer: Timer?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopHoverPolling()
        guard window != nil else { return }

        // Space switches and display changes can suspend NSTrackingArea delivery
        // without sending mouseExited. Poll the actual screen pointer so hover
        // state is reconciled even when AppKit drops those transition events.
        refreshPointerState()
        let timer = Timer(timeInterval: 0.10, repeats: true) { [weak self] _ in
            self?.refreshPointerState()
        }
        hoverPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    deinit {
        hoverPollTimer?.invalidate()
    }

    private func stopHoverPolling() {
        hoverPollTimer?.invalidate()
        hoverPollTimer = nil
    }

    private func refreshPointerState() {
        guard let window else {
            onChange?(false)
            return
        }
        let isInside = window.isVisible && window.frame.contains(NSEvent.mouseLocation)
        onChange?(isInside)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onChange?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
