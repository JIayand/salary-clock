import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: SalaryClockModel
    @State private var selectedCategory = "薪资与家庭"
    @State private var selectedTaxProfile = "self"
    @State private var manualSearch = ""
    @AppStorage("salary-clock.hasSeenSetupGuide") private var hasSeenSetupGuide = false

    private var profileWorkdays: Binding<Set<Int>> {
        Binding(
            get: {
                model.settings.familyMembers.first(where: { $0.id.uuidString == selectedTaxProfile })?.workdays
                    ?? model.settings.workdays
            },
            set: { value in
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    model.settings.workdays = value
                    return
                }
                model.settings.familyMembers[index].workdays = value
            }
        )
    }

    private var schedulePreset: Binding<String> {
        Binding(
            get: {
                if profileWorkdays.wrappedValue == Set([2, 3, 4, 5, 6]) { return "双休" }
                if profileWorkdays.wrappedValue == Set([2, 3, 4, 5, 6, 7]) { return "单休" }
                return "自定义"
            },
            set: { value in
                if value == "双休" { profileWorkdays.wrappedValue = Set([2, 3, 4, 5, 6]) }
                if value == "单休" { profileWorkdays.wrappedValue = Set([2, 3, 4, 5, 6, 7]) }
            }
        )
    }

    private var categories: [(String, String, String)] {
        [("薪资与家庭", "yensign.circle", "薪资、人员工作制度与税后计算"),
         ("桌面显示", "rectangle.on.rectangle", "挂件布局、统计与位置锁定"),
         ("提醒与目标", "bell.badge", "愿望清单与下班提醒"),
         ("外观与隐私", "paintpalette", "主题、透明度与隐私模式"),
         ("操作手册", "book.closed", "功能说明、搜索与使用案例"),
         ("关于", "info.circle", "应用版本与产品信息")]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !hasSeenSetupGuide {
                            setupGuideCard
                        }
                        if selectedCategory == "薪资与家庭" {
                            // Person selection and every per-person work rule stay together
                            // at the top, independently of the salary calculation card.
                            profileSelectorSection
                            scheduleSection
                            profileScheduleSection
                            sectionHeading
                            salarySection
                            calculationNote
                            familySection
                            taxSection
                        } else {
                            sectionHeading
                            if selectedCategory == "桌面显示" {
                                displaySection
                            } else if selectedCategory == "提醒与目标" {
                                wishListSection
                                reminderSection
                            } else if selectedCategory == "操作手册" {
                                manualSection
                            } else if selectedCategory == "关于" {
                                aboutSection
                            } else {
                                appearanceSection
                                privacySection
                            }
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.automatic)
                .background(Color(nsColor: .windowBackgroundColor))
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .frame(minWidth: 720, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
        .preferredColorScheme(nil)
        .environment(\.locale, model.settings.language.locale)
    }

    private var setupGuideCard: some View {
        SettingsCard(title: "首次使用引导", subtitle: "先完成以下必填信息，薪资时钟才能按你的实际工作制度计算收入", icon: "list.clipboard") {
            VStack(alignment: .leading, spacing: 8) {
                Label("必填：月薪（本人及需要统计的家庭成员分别填写）", systemImage: "asterisk.circle.fill")
                Label("必填：每周至少选择一个工作日", systemImage: "asterisk.circle.fill")
                Label("必填：上班时间和下班时间", systemImage: "asterisk.circle.fill")
                Text("午休时间、年终奖、税后扣除和提醒均可按实际情况补充；不使用的可保持默认值。设置会自动保存。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                HStack {
                    Button("查看操作手册") { selectedCategory = "操作手册" }
                        .buttonStyle(.bordered).controlSize(.small)
                    Spacer()
                    Button("知道了") { hasSeenSetupGuide = true }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
            }
            .font(.system(size: 11))
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("设置分类")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 11).padding(.top, 18).padding(.bottom, 7)
            ForEach(categories, id: \.0) { item in
                let selected = selectedCategory == item.0
                Button { selectedCategory = item.0 } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.1)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 20)
                            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LocalizedStringKey(item.0)).font(.system(size: 12, weight: selected ? .semibold : .medium))
                                .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.82))
                            Text(LocalizedStringKey(item.2)).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if selected { RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3, height: 24) }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 10)
                    .background(selected ? Color.accentColor.opacity(0.10) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .animation(.easeInOut(duration: 0.16), value: selected)
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Label("自动保存", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.green)
                Text("修改后立即生效").font(.system(size: 9)).foregroundStyle(.tertiary)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 9))
            .padding(10)
        }
        .frame(width: 190)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }

    private var sectionHeading: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(selectedCategory)).font(.system(size: 21, weight: .bold))
            Text(LocalizedStringKey(categories.first(where: { $0.0 == selectedCategory })?.2 ?? "管理薪资时钟偏好设置"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 2)
    }


    private var profileSelectorSection: some View {
        SettingsCard(title: "当前人员", subtitle: "切换人员后，薪资、每周工作日、上下班时间、午休和税后设置都会同步切换", icon: "person.crop.circle") {
            ScrollView(.horizontal) {
                HStack(spacing: 7) {
                    taxProfileTab(title: "本人", id: "self")
                    ForEach(model.settings.familyMembers) { member in
                        taxProfileTab(title: member.name.isEmpty ? "未命名成员" : member.name, id: member.id.uuidString)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var salarySection: some View {
        SettingsCard(title: "薪资计算", subtitle: "设置当前人员的月薪和显示计算方式", icon: "yensign.circle") {
            HStack {
                HStack(spacing: 3) {
                    Text("月薪（元）")
                    Text("*").foregroundStyle(.red).fontWeight(.bold)
                }
                Spacer()
                TextField("请输入月薪", value: profileDoubleBinding(\.monthlySalary, member: \.monthlySalary), format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 142)
            }
            HStack {
                Text("年终奖（元/年）")
                Spacer()
                TextField("未发放可填 0", value: profileDoubleBinding(\.yearEndBonus, member: \.yearEndBonus), format: .number.precision(.fractionLength(0...2)))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 142)
            }
            Text("年终奖按填写金额计入年薪，不参与今日已赚、时薪和日薪计算。税后模式下暂不单独估算年终奖个税。")
                .font(.system(size: 10)).foregroundStyle(.secondary)
            Divider()
            HStack {
                Text("主显示内容")
                Spacer()
                Picker("主显示内容", selection: $model.settings.mode) {
                    ForEach(DisplayMode.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
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

    private var profileScheduleSection: some View {
        SettingsCard(title: "当前人员工作时间", subtitle: "当前选中人员独立保存上下班和午休时间", icon: "clock") {
            VStack(alignment: .leading, spacing: 10) {
                Label("工作时段", systemImage: "sun.max")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 10) {
                    timeField("上班时间 *", hour: profileIntBinding(\.startHour, member: \.startHour), minute: profileIntBinding(\.startMinute, member: \.startMinute))
                    timeField("下班时间 *", hour: profileIntBinding(\.endHour, member: \.endHour), minute: profileIntBinding(\.endMinute, member: \.endMinute))
                }
                Divider().overlay(Color.primary.opacity(0.04))
                Label("午休时段", systemImage: "cup.and.saucer")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], alignment: .leading, spacing: 10) {
                    timeField("午休开始", hour: profileIntBinding(\.lunchStartHour, member: \.lunchStartHour), minute: profileIntBinding(\.lunchStartMinute, member: \.lunchStartMinute))
                    timeField("午休结束", hour: profileIntBinding(\.lunchEndHour, member: \.lunchEndHour), minute: profileIntBinding(\.lunchEndMinute, member: \.lunchEndMinute))
                }
            }
            .padding(12)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private var selectedProfileName: String {
        guard let member = selectedTaxMember else { return "本人" }
        return member.name.isEmpty ? "未命名成员" : member.name
    }

    private var familySection: some View {
        SettingsCard(title: "家庭成员", subtitle: "管理家庭成员；每位成员的薪资、工作时间和税后参数均可独立配置", icon: "person.2.fill") {
            if model.settings.familyMembers.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "person.3.sequence.fill").font(.system(size: 26)).foregroundStyle(.secondary.opacity(0.7))
                    Text("还没有家庭成员").font(.system(size: 12, weight: .semibold))
                    Text("添加成员后，可在桌面挂件中查看每个人的实时收入")
                        .font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button { addFamilyMember() } label: { Label("添加第一位成员", systemImage: "plus") }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            } else {
                VStack(spacing: 9) {
                    ForEach($model.settings.familyMembers) { $member in
                        HStack(spacing: 11) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.11))
                                Text(String(member.name.prefix(1)).isEmpty ? AppLocalization.string("家", language: model.settings.language) : String(member.name.prefix(1)))
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.accentColor)
                            }
                            .frame(width: 38, height: 38)
                            VStack(alignment: .leading, spacing: 5) {
                                TextField("成员名称", text: $member.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .textFieldStyle(.plain)
                            }
                            Spacer(minLength: 4)
                            Button(role: .destructive) {
                                model.settings.familyMembers.removeAll { $0.id == member.id }
                                if selectedTaxProfile == member.id.uuidString { selectedTaxProfile = "self" }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(Color.primary.opacity(0.045), in: Circle())
                            }
                            .buttonStyle(.plain).help("删除成员")
                        }
                        .padding(11)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.045), lineWidth: 1))
                    }
                }
                Button { addFamilyMember() } label: {
                    Label("添加家庭成员", systemImage: "plus.circle.fill")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered).controlSize(.regular)
            }
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle.fill").foregroundStyle(.secondary)
                helpText("成员可在页面顶部人员切换栏中独立设置薪资、每周工作日、上下班时间、午休及税后参数。中国法定节假日及调休日历由全员共用。隐私模式开启时会同时隐藏所有人员收入金额。")
            }
        }
    }

    private func addFamilyMember() {
        let index = model.settings.familyMembers.count + 1
        var member = FamilySalaryMember(name: AppLocalization.string("家庭成员", language: model.settings.language) + " \(index)", monthlySalary: 10000)
        member.workdays = model.settings.workdays
        member.startHour = model.settings.startHour
        member.startMinute = model.settings.startMinute
        member.endHour = model.settings.endHour
        member.endMinute = model.settings.endMinute
        member.lunchStartHour = model.settings.lunchStartHour
        member.lunchStartMinute = model.settings.lunchStartMinute
        member.lunchEndHour = model.settings.lunchEndHour
        member.lunchEndMinute = model.settings.lunchEndMinute
        model.settings.familyMembers.append(member)
        selectedTaxProfile = member.id.uuidString
    }

    private var taxSection: some View {
        SettingsCard(title: "税后工资", subtitle: "按人员分别设置；不开启时使用税前月薪计算", icon: "receipt") {
            if selectedTaxProfile != "self", let member = selectedTaxMember {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill").foregroundStyle(.tint)
                    Text("正在编辑：\(member.name.isEmpty ? "未命名成员" : member.name)")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("独立配置").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                }
            }

            Toggle("使用税后工资计算收入", isOn: taxBoolBinding(\.useAfterTaxSalary, member: \.useAfterTaxSalary))
                .toggleStyle(.switch)

            if taxBoolBinding(\.useAfterTaxSalary, member: \.useAfterTaxSalary).wrappedValue {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.tint)
                        Text("以下参数仅对当前选中人员生效，填写工资单上的个人缴费基数和比例。")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        taxInputGroup(title: "社保缴费", baseTitle: "社保缴费基数（元/月）", baseHelp: "不是到手工资，也不一定等于本月税前工资。按工资单或随申办中显示的社保缴费基数填写。", base: taxDoubleBinding(\.socialInsuranceBase, member: \.socialInsuranceBase), rateTitle: "个人缴费比例", rate: taxDoubleBinding(\.socialInsuranceRate, member: \.socialInsuranceRate), ratePlaceholder: "10.5")
                        taxInputGroup(title: "住房公积金", baseTitle: "公积金缴费基数（元/月）", baseHelp: "按工资单或公积金账户显示的缴存基数填写。它可能与社保缴费基数不同。", base: taxDoubleBinding(\.housingFundBase, member: \.housingFundBase), rateTitle: "个人缴存比例", rate: taxDoubleBinding(\.housingFundRate, member: \.housingFundRate), ratePlaceholder: "7")
                    }
                    HStack {
                        Text("预计个人社保 + 公积金")
                        Spacer()
                        Text("¥ " + String(format: "%.2f", selectedTaxContributions))
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text("专项附加扣除（元/月）")
                                HelpPopover(title: "专项附加扣除怎么填？", message: "填写个人所得税专项附加扣除的月度合计，例如子女教育、继续教育、住房贷款利息、住房租金、赡养老人等。没有符合条件的扣除项目就填 0。")
                            }
                            Text("按当前人员实际享受的月度扣除合计填写").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        TextField("0", value: taxDoubleBinding(\.monthlySpecialDeductions, member: \.monthlySpecialDeductions), format: .number.precision(.fractionLength(0...2)))
                            .multilineTextAlignment(.trailing).textFieldStyle(.roundedBorder).frame(width: 112)
                    }
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("预计税后月薪").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text("含社保、公积金个人缴纳及预估个税").font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text("¥ " + String(format: "%.2f", selectedTaxSnapshot.netMonthlySalary))
                            .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                    }
                    HStack {
                        Text("预计月度个税")
                        Spacer()
                        Text("¥ " + String(format: "%.2f", selectedTaxSnapshot.tax))
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    }
                    helpText("个税按全年 12 个月工资相同估算，实际金额会受累计预扣、年终奖及其他扣除影响。")
                }
                .padding(12)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text("当前按税前月薪计算。开启上方开关后，可填写社保、公积金和专项附加扣除信息。")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: taxBoolBinding(\.useAfterTaxSalary, member: \.useAfterTaxSalary).wrappedValue)
    }

    private func taxInputGroup(
        title: String,
        baseTitle: String,
        baseHelp: String,
        base: Binding<Double>,
        rateTitle: String,
        rate: Binding<Double>,
        ratePlaceholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 10, weight: .semibold))
            HStack(spacing: 4) {
                Text(baseTitle).font(.system(size: 9)).foregroundStyle(.secondary)
                HelpPopover(title: baseTitle, message: baseHelp)
            }
            TextField(baseTitle, value: base, format: .number.precision(.fractionLength(0...2)))
                .textFieldStyle(.roundedBorder)
            Text(rateTitle).font(.system(size: 9)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(ratePlaceholder, value: rate, format: .number.precision(.fractionLength(0...2)))
                    .textFieldStyle(.roundedBorder)
                Text("%").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.85), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func taxProfileTab(title: String, id: String) -> some View {
        let selected = selectedTaxProfile == id
        return Button {
            selectedTaxProfile = id
        } label: {
            HStack(spacing: 5) {
                Image(systemName: id == "self" ? "person.crop.circle" : "person")
                    .font(.system(size: 10, weight: .medium))
                Text(title).font(.system(size: 11, weight: selected ? .semibold : .medium))
            }
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.045),
                        in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.accentColor.opacity(0.24) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var selectedTaxMember: FamilySalaryMember? {
        model.settings.familyMembers.first { $0.id.uuidString == selectedTaxProfile }
    }

    private var selectedTaxSnapshot: SalarySnapshot {
        guard let member = selectedTaxMember else { return model.snapshot }
        return model.snapshot(for: member)
    }

    private var selectedTaxContributions: Double {
        guard let member = selectedTaxMember else {
            return SalaryCalculator.estimatedMonthlyContributions(settings: model.settings)
        }
        var settings = model.settings
        settings.monthlySalary = member.monthlySalary
        settings.socialInsuranceBase = member.socialInsuranceBase
        settings.socialInsuranceRate = member.socialInsuranceRate
        settings.housingFundBase = member.housingFundBase
        settings.housingFundRate = member.housingFundRate
        return SalaryCalculator.estimatedMonthlyContributions(settings: settings)
    }

    private func profileDoubleBinding(
        _ setting: WritableKeyPath<SalarySettings, Double>,
        member memberKeyPath: WritableKeyPath<FamilySalaryMember, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    return model.settings[keyPath: setting]
                }
                return model.settings.familyMembers[index][keyPath: memberKeyPath]
            },
            set: { value in
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    model.settings[keyPath: setting] = value
                    return
                }
                model.settings.familyMembers[index][keyPath: memberKeyPath] = value
            }
        )
    }

    private func profileIntBinding(
        _ setting: WritableKeyPath<SalarySettings, Int>,
        member memberKeyPath: WritableKeyPath<FamilySalaryMember, Int>
    ) -> Binding<Int> {
        Binding(
            get: {
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    return model.settings[keyPath: setting]
                }
                return model.settings.familyMembers[index][keyPath: memberKeyPath]
            },
            set: { value in
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    model.settings[keyPath: setting] = value
                    return
                }
                model.settings.familyMembers[index][keyPath: memberKeyPath] = value
            }
        )
    }

    private func taxDoubleBinding(
        _ setting: WritableKeyPath<SalarySettings, Double>,
        member memberKeyPath: WritableKeyPath<FamilySalaryMember, Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    return model.settings[keyPath: setting]
                }
                return model.settings.familyMembers[index][keyPath: memberKeyPath]
            },
            set: { value in
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    model.settings[keyPath: setting] = value
                    return
                }
                model.settings.familyMembers[index][keyPath: memberKeyPath] = value
            }
        )
    }

    private func taxBoolBinding(
        _ setting: WritableKeyPath<SalarySettings, Bool>,
        member memberKeyPath: WritableKeyPath<FamilySalaryMember, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: {
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    return model.settings[keyPath: setting]
                }
                return model.settings.familyMembers[index][keyPath: memberKeyPath]
            },
            set: { value in
                guard let index = model.settings.familyMembers.firstIndex(where: { $0.id.uuidString == selectedTaxProfile }) else {
                    model.settings[keyPath: setting] = value
                    return
                }
                model.settings.familyMembers[index][keyPath: memberKeyPath] = value
            }
        )
    }

    private var wishListSection: some View {
        SettingsCard(title: "愿望清单", subtitle: "记录目标金额和已存金额，查看完成进度", icon: "target") {
            ForEach($model.settings.wishList) { $wish in
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        TextField("目标名称，例如：旅行 / 新电脑", text: $wish.name).textFieldStyle(.roundedBorder)
                        Button(role: .destructive) {
                            model.settings.wishList.removeAll { $0.id == wish.id }
                        } label: { Image(systemName: "trash").foregroundStyle(.secondary) }
                            .buttonStyle(.plain).help("删除目标")
                    }
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("目标金额").font(.system(size: 9)).foregroundStyle(.secondary)
                            TextField("目标金额", value: $wish.targetAmount, format: .number.precision(.fractionLength(0...2))).textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("已存金额").font(.system(size: 9)).foregroundStyle(.secondary)
                            TextField("已存金额", value: $wish.savedAmount, format: .number.precision(.fractionLength(0...2))).textFieldStyle(.roundedBorder)
                        }
                    }
                    ProgressView(value: wish.targetAmount > 0 ? min(1, max(0, wish.savedAmount / wish.targetAmount)) : 0)
                    HStack {
                        Text(AppLocalization.string("完成", language: model.settings.language) + " \(wish.targetAmount > 0 ? Int(min(100, max(0, wish.savedAmount / wish.targetAmount * 100))) : 0)%")
                        Spacer()
                        Text(AppLocalization.string("还差", language: model.settings.language) + " ¥\(String(format: "%.2f", max(0, wish.targetAmount - wish.savedAmount)))")
                    }.font(.system(size: 10, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                }
                if wish.id != model.settings.wishList.last?.id { Divider() }
            }
            Button {
                model.settings.wishList.append(SalaryWish(name: AppLocalization.string("新目标", language: model.settings.language), targetAmount: 10000))
            } label: {
                Label("添加愿望目标", systemImage: "plus.circle.fill")
            }.buttonStyle(.borderless)
        }
    }

    private var aboutSection: some View {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String ?? "—"

        return SettingsCard(title: "薪资时钟", subtitle: "应用信息", icon: "info.circle") {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("薪资时钟").font(.system(size: 15, weight: .semibold))
                    Text("Salary Clock").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            HStack {
                Label("版本号", systemImage: "tag")
                Spacer()
                Text("v\(version)").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            HStack {
                Label("构建版本", systemImage: "hammer")
                Spacer()
                Text(build).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Text("版本信息从应用自身的构建配置读取。")
                .font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }

    private var privacySection: some View {
        SettingsCard(title: "隐私模式", subtitle: "隐藏桌面挂件中的所有收入金额", icon: "eye.slash") {
            Toggle("隐藏收入金额", isOn: $model.settings.privacyMode).toggleStyle(.switch)
            helpText("开启后，今日收入、本周 / 本月累计、时薪、日薪、秒薪和年薪均显示为遮罩；工作进度百分比仍正常显示。可通过挂件上的眼睛图标快速切换。")
        }
    }

    private var reminderSection: some View {
        SettingsCard(title: "下班提醒", subtitle: "到设定时间后发送系统通知", icon: "bell") {
            Toggle("启用下班提醒", isOn: $model.settings.afterWorkReminderEnabled).toggleStyle(.switch)
            HStack {
                Text("提醒时间")
                Spacer()
                Picker("小时", selection: $model.settings.afterWorkReminderHour) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.labelsHidden().frame(width: 78)
                Text(":")
                Picker("分钟", selection: $model.settings.afterWorkReminderMinute) {
                    ForEach([0, 5, 10, 15, 20, 30, 40, 45, 50, 55], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.labelsHidden().frame(width: 78)
            }
            HStack(spacing: 10) {
                Button("发送测试通知") { model.sendTestReminder() }
                    .buttonStyle(.bordered).controlSize(.small)
                Text(model.reminderStatus)
                    .font(.system(size: 10)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            helpText("启用后需要允许 macOS 通知权限。提醒每天在设定时间触发；修改工作时间不会自动改变提醒时间。若未收到通知，先点击“发送测试通知”检查权限和系统投递。")
        }
    }

    private var scheduleSection: some View {
        SettingsCard(title: "当前人员每周工作制度", subtitle: "当前选中人员独立设置工作日；中国法定节假日及调休日历全员共用", icon: "calendar") {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill").foregroundStyle(.tint)
                Text("正在设置：\(selectedProfileName)").font(.system(size: 11, weight: .semibold))
                Spacer()
                Text("独立保存").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }
            HStack {
                HStack(spacing: 3) {
                    Text("每周工作制度")
                    Text("*").foregroundStyle(.red).fontWeight(.bold)
                }
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
                    let selected = profileWorkdays.wrappedValue.contains(day)
                    Button {
                        var days = profileWorkdays.wrappedValue
                        if selected { days.remove(day) }
                        else { days.insert(day) }
                        profileWorkdays.wrappedValue = days
                    } label: {
                        Text(LocalizedStringKey(label)).font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 29)
                            .foregroundStyle(selected ? Color.white : Color.secondary)
                            .background(selected ? Color.accentColor : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
            helpText("以上星期设置只作用于当前人员。官方节假日和补班安排优先于当前人员的每周规则；关闭节假日日历后，仅按当前人员的星期设置计算。")
            Toggle(isOn: $model.settings.useChinaHolidayCalendar) {
                Label("中国法定节假日及调休", systemImage: "calendar.badge.clock")
            }
            .toggleStyle(.switch)
        }
    }

    private var displaySection: some View {
        SettingsCard(title: "桌面显示", subtitle: "关闭不需要的项目，让挂件保持简洁", icon: "rectangle.on.rectangle") {
            VStack(spacing: 0) {
                ToggleRow(title: "紧凑悬浮模式", subtitle: "默认收起，鼠标移入展开详情", isOn: $model.settings.compactMode) {
                    HelpPopover(title: "紧凑悬浮模式", message: "开启后，挂件平时只显示今日收入和进度条。鼠标移入挂件会自动展开全部统计，移出后收起。点击挂件可以固定展开；展开状态下点击收起图标可恢复自动收起。")
                }
                Divider().padding(.leading, 2)
                ToggleRow(title: "锁定挂件位置", subtitle: "开启后禁止拖动窗口，避免误移动", isOn: $model.settings.windowLocked) {
                    HelpPopover(title: "锁定挂件位置", message: "也可以直接点击桌面挂件顶部的锁形图标快速锁定或解锁。")
                }
                Divider().padding(.leading, 2)
                ToggleRow(title: "始终置顶", subtitle: "关闭时位于桌面层级；开启后显示在其他应用窗口上方", isOn: $model.settings.alwaysOnTop) {
                    HelpPopover(title: "始终置顶", message: "默认关闭时挂件位于 macOS 桌面层级，显示在桌面上但位于普通应用窗口后方；开启后挂件保持在其他普通窗口上方。挂件仅显示在当前桌面空间，不会自动出现在所有桌面空间。设置立即生效。")
                }
                Divider().padding(.leading, 2)
                HStack {
                    Text("数字变化动画")
                    Spacer()
                    Picker("数字变化动画", selection: $model.settings.numberAnimation) {
                        ForEach(NumberAnimationStyle.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
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
                    HStack(spacing: 6) {
                        DisplayToggle(title: "秒薪", icon: "timer", isOn: $model.settings.showSecondRate)
                        if model.settings.showSecondRate {
                            decimalPicker(selection: $model.settings.secondRateDecimals, range: 0...6)
                                .frame(width: 68)
                        }
                    }
                    DisplayToggle(title: "年薪", icon: "calendar", isOn: $model.settings.showAnnualSalary)
                }
                .padding(.top, 10)
                if model.settings.showWorkDuration {
                    Divider().padding(.top, 8)
                    HStack {
                        Label("时间显示格式", systemImage: "timer")
                        Spacer()
                        Picker("时间显示格式", selection: $model.settings.durationDisplay) {
                            ForEach(DurationDisplay.allCases) { item in
                                Text(LocalizedStringKey(item.rawValue)).tag(item)
                            }
                        }
                        .labelsHidden().frame(width: 115)
                    }
                }
                ToggleRow(title: "沙漏动画", subtitle: "在已工作 / 剩余时间旁显示动态沙漏", isOn: $model.settings.hourglassAnimationEnabled) { EmptyView() }
            }
        }
    }

    private var manualSection: some View {
        SettingsCard(title: "操作手册", subtitle: "搜索功能说明，查看具体操作步骤和使用案例", icon: "book.closed") {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索功能，例如：双休、沙漏、隐私、成员", text: $manualSearch)
                    .textFieldStyle(.plain)
                if !manualSearch.isEmpty {
                    Button { manualSearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                        .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 9))

            let articles: [(String, String, String, String)] = [
                ("首次使用与自动保存", "开始使用、设置、保存、菜单栏、快捷键", "首次打开设置时会显示“首次使用引导”。红色 * 表示必填：月薪、每周工作日、上班时间和下班时间；每周至少选择一个工作日。午休、年终奖、税后参数和提醒可按需填写。所有设置修改后立即保存，不需要点击保存按钮。设置窗口可调整大小，内容区域可独立滚动；关闭设置窗口不会退出应用。通过菜单栏图标或应用菜单可隐藏、恢复挂件。Option + Command + H 可快速隐藏或恢复挂件，Command + , 可打开或关闭设置。", "建议首次使用先填写月薪、工作日、上下班和午休，再检查挂件金额是否符合预期。"),
                ("本人薪资与主显示", "月薪、年终奖、金额、进度、主显示内容", "进入“薪资与家庭”，在“薪资计算”填写当前人员月薪和年终奖。年终奖计入年薪展示，不参与今日收入、日薪和时薪。主显示内容选择“金额”时，主数字显示今日已赚金额，进度作为辅助信息；选择“进度”时，主数字显示今日工作进度百分比，今日金额作为辅助信息，不会重复显示第二份进度。", "想优先看收入，选择“金额”；想优先看今天完成了多少工作时间，选择“进度”。"),
                ("金额与百分比精度", "金额小数位、百分比小数位、数字精度", "在“薪资与家庭 → 薪资计算”分别设置金额小数位和百分比小数位。金额支持 0–6 位，百分比支持 0–4 位，两项互不影响；设置会同步影响挂件中对应数字。", "例如金额设为 2 位、百分比设为 1 位，金额显示 ¥123.45，进度显示 68.2%。"),
                ("每周工作制度", "双休、单休、自定义、工作日、星期", "在“薪资与家庭 → 工作制度”选择双休、单休或自定义。双休默认周一至周五工作；单休默认周一至周六工作；自定义可逐一勾选星期。工作制度决定哪些日期参与计薪。", "如实行周三休息、周日上班，选择自定义并勾选实际工作日。"),
                ("法定节假日与调休", "中国节假日、节日、补班、调休、日历", "开启“中国法定节假日及调休”后，内置官方节假日和补班安排优先于每周工作制度；关闭后仅按每周工作日计算。目前内置 2026、2027 年安排，其他年份按每周工作制度处理。", "例如周一至周五双休规则下，法定节假日会按休息日处理，官方周末补班日会按工作日计薪。"),
                ("上下班与午休时间", "上班时间、下班时间、午休、有效工时", "在“薪资与家庭”设置当前人员的上班和下班时间，以及午休开始、结束时间。午休区间从每日有效计薪工时中扣除；工作时长、今日进度和收入会按有效工时计算。家庭成员可分别设置自己的时间。当前不支持跨午夜班次。", "例如 09:00–18:00、12:00–13:00 午休，每日有效工作时间为 8 小时。"),
                ("税后工资估算", "税后、社保、公积金、缴费基数、专项附加扣除、个税", "在“薪资与家庭 → 税后工资”开启“使用税后工资计算收入”。按工资单分别填写社保、公积金缴费基数和个人缴费比例，并填写每月专项附加扣除合计。页面会展示预计个人缴费、预计税后月薪和预计月度个税。该结果为估算，实际个税受累计预扣、其他收入及扣除影响；不确定的专项附加扣除可先填 0。", "社保和公积金基数不一定相同，应按工资单或官方账户数据分别填写，不要直接把到手工资当缴费基数。"),
                ("家庭成员管理", "添加成员、删除成员、成员姓名、家庭收入", "在“薪资与家庭 → 家庭成员”添加成员并修改姓名。每位成员有独立月薪、年终奖、工作日、上下班、午休及税后参数。切换页面顶部人员标签即可编辑对应人员；删除成员会移除该成员配置。桌面挂件展开后可查看家庭收入列表；桌面 Widget 的“超大”尺寸会同时展示本人及全部家庭成员的今日收入、进度和各自上下班时间。展开成员详情时窗口会自动测量内容高度，并在屏幕可视区域内调整窗口尺寸，避免首次展开时内容被裁切。", "先添加成员，再切换到成员标签设置其薪资和工作时间；不要误以为切换人员会覆盖本人设置。"),
                ("桌面统计项目", "今日进度、已工作、剩余、本周累计、本月累计、时薪、日薪、秒薪、年薪", "在“桌面显示”逐项开启或关闭统计。可控制今日进度、已工作/剩余时间、本周累计、本月累计、时薪、日薪、秒薪和年薪是否展示。开启秒薪后可单独设置秒薪小数位，默认 4 位，范围 0–6 位；不影响金额、时薪和日薪精度。关闭不需要的项目可缩短挂件高度；家庭成员详情遵循相同统计开关。", "只关心今日收入时，可关闭本周、本月、时薪、日薪等项目，让挂件更简洁。"),
                ("工作时长格式与沙漏", "时分秒、时分、沙漏动画、倒计时", "开启“已工作 / 剩余”后，可选择“时分秒”或“时分”。开启“沙漏动画”会在已工作/剩余时间旁显示动态沙漏；关闭后只显示时间文字。", "需要精确观察秒级变化时选择时分秒；不需要秒级信息时选择时分。"),
                ("窗口层级与始终置顶", "桌面显示、普通窗口、始终置顶、覆盖其他应用", "在“桌面显示 → 始终置顶”配置窗口层级。默认关闭，挂件位于桌面层级，普通应用窗口会显示在它前面；开启后挂件保持在其他普通应用窗口上方。挂件只属于当前桌面空间，不会自动出现在所有桌面空间。设置即时生效，无需重启。", "日常办公建议关闭；需要随时查看收入时再开启。"),
                ("紧凑模式与展开", "紧凑模式、鼠标悬停、点击展开、收起", "在“桌面显示”开启“紧凑悬浮模式”。挂件默认收起，鼠标移入后根据挂件所在屏幕的垂直位置自动选择展开方向：位于屏幕下半区时向上展开，位于上半区时向下展开，避免详情超出屏幕边缘；移出后自动收起。点击紧凑挂件可固定展开，再次点击可切换。展开状态下可通过收起图标恢复紧凑显示。", "适合长期放在屏幕边缘：平时只显示核心收入，查看统计时将鼠标移入。"),
                ("拖动与位置锁定", "拖动、移动、锁定、解锁、窗口位置", "未锁定时，拖动挂件顶部左侧的文字区域即可移动窗口；右侧锁定、隐私和设置按钮仍可正常点击。点击挂件上的锁形按钮，或在“桌面显示”开启“锁定挂件位置”，即可禁止拖动；再次解锁后恢复拖动。位置会随窗口移动保存。", "将挂件拖到屏幕合适位置后点击锁形按钮，避免误触移动。"),
                ("数字变化动画", "数字滚动、平滑淡变、动画", "在“桌面显示 → 数字变化动画”选择“数字滚动”或“平滑淡变”。前者以数字滚动方式呈现收入变化，后者使用淡入淡出过渡。", "偏好稳定、柔和视觉效果时选择平滑淡变；希望突出金额实时变化时选择数字滚动。"),
                ("愿望清单", "愿望、目标金额、已存金额、完成进度", "进入“提醒与目标 → 愿望清单”，添加目标名称、目标金额和已存金额。后续可修改已存金额，应用会根据已存金额与目标金额计算完成进度；不再需要的目标可删除。", "例如添加“旅行基金”，目标金额 10000 元，已存 3500 元，完成进度为 35%。"),
                ("下班提醒与系统通知", "下班提醒、提醒时间、通知权限、测试通知", "进入“提醒与目标 → 下班提醒”，开启提醒并设置每天的提醒时、分。首次使用需要允许 macOS 通知权限；可点击“发送测试通知”检查系统是否正常投递。提醒时间独立于下班时间，修改工作时间不会自动修改提醒时间。", "如果没有收到提醒，先发送测试通知，再检查 macOS“系统设置 → 通知”中的薪资时钟权限。"),
                ("隐私模式", "隐私、隐藏金额、遮罩、眼睛按钮", "在“外观与隐私”开启隐私模式，或点击挂件上的眼睛按钮快速切换。隐私模式会遮挡本人和家庭成员的收入金额，包括今日、本周、本月、时薪和日薪等金额；工作进度百分比和时间仍可见。", "屏幕共享或演示时开启隐私模式；结束后可再次点击眼睛按钮恢复金额。"),
                ("主题与背景透明度", "主题、深空、纸感、霓虹、海盐蓝、日落橙、石墨灰、透明度", "进入“外观与隐私 → 外观”选择深空、纸感、霓虹、海盐蓝、日落橙或石墨灰主题，并拖动背景透明度滑块调整挂件背景。设置立即生效并自动保存。", "深色桌面可选择深空或石墨灰；希望浅色外观可选择纸感。"),
                ("界面语言", "语言、简体中文、繁体中文、English", "在“外观与隐私 → 外观”选择简体中文、繁体中文或 English。设置页、桌面挂件、菜单栏和系统通知会跟随语言切换。", "切换语言后无需重启，界面会自动应用所选语言。"),
                ("薪资计算口径与限制", "日薪、时薪、秒薪、今日收入、本周、本月、加班", "日薪按月薪除以当月计薪工作日计算；时薪按日薪除以每日有效工时计算；今日收入按今日有效工作进度估算。本周和本月累计包含已完成工作日收入及今天的实时进度，午休不计薪。当前不单独计算加班费、请假扣薪和年终奖个税，也不支持跨午夜班次。", "若实际工资包含加班费、绩效或请假扣款，挂件数值应视为按当前规则计算的估算值，而不是工资单结算金额。"),
                ("WidgetKit 桌面小组件", "Widget、桌面小组件、小中大、App Group", "项目包含 WidgetKit 小、中、大尺寸组件源码，与主程序共用薪资计算逻辑，并通过 App Group 共享配置。Widget 刷新由 macOS 系统调度，不保证 100ms 实时更新。当前源码和构建脚本已提供，但完整 Xcode 工程构建、签名、嵌入和系统安装验证仍需完整 Xcode 与开发者签名环境。", "需要使用系统桌面小组件时，先按 README 的 WidgetKit 构建说明完成签名和安装；普通悬浮挂件不依赖 WidgetKit。"),
                ("设置迁移与数据保存", "自动保存、本地配置、旧版本、迁移、备份", "设置更改会自动保存到本地配置，无需手动保存。应用升级时会为新增配置字段补齐默认值，并迁移旧版本家庭成员的工作日和工作时间配置。重新安装或迁移设备前，建议先备份应用本地配置数据。", "升级后若发现人员工作时间不符合预期，检查本人和各家庭成员的独立设置。")
            ]
            let filtered = articles.filter { manualSearch.isEmpty || ($0.0 + $0.1 + $0.2 + $0.3).localizedCaseInsensitiveContains(manualSearch) }
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.system(size: 22)).foregroundStyle(.tertiary)
                    Text("没有找到相关内容").font(.system(size: 12, weight: .medium))
                    Text("试试其他关键词").font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                ForEach(Array(filtered.enumerated()), id: \.offset) { _, article in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(article.0).font(.system(size: 13, weight: .semibold))
                        Text(article.2).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Label(article.3, systemImage: "lightbulb").font(.system(size: 10)).foregroundStyle(Color.accentColor).fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var appearanceSection: some View {
        SettingsCard(title: "外观", subtitle: "调整主题和背景透明度", icon: "paintpalette") {
            HStack {
                Text("界面语言")
                Spacer()
                Picker("界面语言", selection: $model.settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.title)).tag(language)
                    }
                }
                .labelsHidden().frame(width: 145)
            }
            Divider()
            HStack {
                Text("主题")
                Spacer()
                Picker("主题", selection: $model.settings.theme) {
                    ForEach(WidgetTheme.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
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

    private func decimalPicker(selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Picker("小数位", selection: selection) {
            ForEach(range, id: \.self) { Text("\($0) 位").tag($0) }
        }
        .labelsHidden().frame(width: 95)
    }

    @ViewBuilder
    private func timeField(_ title: String, hour: Binding<Int>, minute: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(title)).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Picker("小时", selection: hour) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.labelsHidden().frame(maxWidth: .infinity)
                Text(":").foregroundStyle(.secondary)
                Picker("分钟", selection: minute) {
                    ForEach([0, 5, 10, 15, 20, 30, 40, 45, 50, 55], id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
                }.labelsHidden().frame(maxWidth: .infinity)
            }
        }
    }

    private func helpText(_ value: String) -> some View {
        Text(LocalizedStringKey(value)).font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(.tint)
                    .frame(width: 36, height: 36)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(title)).font(.system(size: 13, weight: .semibold))
                    Text(LocalizedStringKey(subtitle)).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            Rectangle().fill(Color.primary.opacity(0.055)).frame(height: 1)
            content
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.primary.opacity(0.065), lineWidth: 1))
        .shadow(color: .black.opacity(0.015), radius: 3, y: 1)
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
                Text(LocalizedStringKey(title)).font(.system(size: 12, weight: .medium))
                Text(LocalizedStringKey(subtitle)).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            help
            Spacer()
            Toggle(LocalizedStringKey(title), isOn: $isOn).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

private struct DisplayToggle: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(LocalizedStringKey(title), systemImage: icon).font(.system(size: 11))
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
                Text(LocalizedStringKey(title)).font(.system(size: 12, weight: .semibold))
                Text(LocalizedStringKey(message)).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(width: 260, alignment: .leading)
        }
        .help(LocalizedStringKey("查看说明"))
    }
}
