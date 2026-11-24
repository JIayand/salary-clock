# 薪资时钟 Salary Clock

一款 macOS 原生桌面薪资挂件。根据月薪、工作日历、上下班时间和午休时段，实时估算今天、本周和本月已赚取的收入。

## 功能

### 桌面悬浮窗口
- SwiftUI + AppKit 原生 macOS 窗口，始终置顶，可拖动
- 内容自适应窗口高度，窗口尺寸以挂件内容为准
- 金额 / 百分比两种主显示模式
- 6 种主题：深空、纸感、霓虹、海盐蓝、日落橙、石墨灰
- 背景透明度调节
- 2–6 位小数，桌面窗口 100ms 更新
- 统计信息可分别开关，支持精简显示

### 收入统计
- 今日已赚取金额 / 今日工作进度
- 本周累计收入、本月累计收入
- 日薪、时薪
- 今日进度百分比、进度条、已工作时间和剩余时间
- 本月计薪工作日数量
- 每项统计都可以在设置中独立开关

### 薪资与日历
- 自定义月薪、每周工作日、上下班时间和午休时间
- 午休区间自动从有效工时中扣除
- 支持国务院公布的 2026、2027 年节假日及调休补班安排
- 可关闭中国节假日日历，退回每周工作日规则
- 旧版本本地设置可自动迁移，新字段使用默认值补齐

### macOS 原生桌面 Widget
- WidgetKit 小、中、大三种尺寸源码
- 与悬浮应用共用薪资计算代码
- 通过 App Group 共享配置
- 支持本周、本月、日薪、时薪和进度显示开关
- WidgetKit 刷新由系统调度，不承诺 100ms 实时刷新

## 计算口径

- 当月计薪工作日：按每周工作日规则计算，并由已内置的官方节假日/补班安排覆盖
- 日薪 = 月薪 ÷ 当月计薪工作日数量
- 时薪 = 日薪 ÷ 当日有效工作小时数
- 今日收入 = 日薪 × 今日有效工作时间进度
- 本周 / 本月累计 = 已完成工作日收入 + 今天实时进度对应收入
- 午休不计薪
- 当前按固定上下班时间计算，不支持跨午夜班次
- 未单独计算加班费、请假扣薪和年终奖

## 项目结构

- `Sources/SalaryClock/SalaryCalculator.swift`：薪资计算、工作日历和配置模型
- `Sources/SalaryClock/SalaryClockModel.swift`：状态更新和本地持久化
- `Sources/SalaryClock/FloatingWidgetView.swift`：桌面悬浮窗口
- `Sources/SalaryClock/SettingsView.swift`：设置界面
- `WidgetExtension/SalaryClockWidget.swift`：WidgetKit 扩展源码
- `Configuration/*.entitlements`：App Group 权限配置
- `scripts/check-calculator.swift`：计算逻辑回归检查脚本
- `scripts/build-mac.sh`：Swift Package 悬浮应用构建脚本
- `project.yml`：XcodeGen App + Widget Extension 工程定义
- `SalaryClock.xcodeproj`：已生成的 Xcode 工程
- `scripts/build-xcode.sh`：生成/更新 Xcode 工程并构建完整应用包

## 构建悬浮应用

需要 macOS 和 Swift 6 工具链：

```bash
swift build -c release
./scripts/build-mac.sh
open "dist/Salary Clock.app"
```

## 计算逻辑检查

```bash
swiftc Sources/SalaryClock/SalaryCalculator.swift scripts/check-calculator.swift -o /tmp/salary-clock-calculator-check
/tmp/salary-clock-calculator-check
```

## WidgetKit 构建状态

WidgetKit 源码已通过当前 macOS SDK 的 Swift 类型检查，并使用 Swift 编译器成功编译为 arm64 Mach-O 扩展可执行文件。**尚未完成 Xcode 工程构建、App Extension 包装、代码签名、嵌入主应用和系统安装验证**。当前开发机只有 Xcode Command Line Tools，没有完整的 Xcode.app；因此无法执行最后的 Xcode 工程构建和安装验证。

已提供 `project.yml`（XcodeGen 工程定义）和 `scripts/build-xcode.sh`。安装完整 Xcode 与 XcodeGen 后，执行：

```bash
brew install xcodegen
./scripts/build-xcode.sh
```

完成 WidgetKit 安装还需要：
1. 在 Xcode 中配置有效的开发团队，并在 Apple Developer 账户注册 App Group：`group.com.jyd.salaryclock`。
2. 确认 App 与 Widget Extension 两个 Target 都使用该 App Group 和各自的 entitlements。
3. App 主 Target 编译 `Sources/SalaryClock`；Widget Extension Target 编译共享的 `SalaryCalculator.swift` 和 `WidgetExtension/SalaryClockWidget.swift`。
4. 完成两个 Target 的签名，再通过 Xcode 构建、安装，并在通知中心/桌面添加 Widget。

WidgetKit 的刷新频率由系统管理，无法保证像悬浮窗口一样每 100ms 更新。

## 节假日数据来源

- 2026 年：国务院办公厅《国办发明电〔2025〕7号》
- 2027 年：国务院办公厅《国办发明电〔2026〕10号》

目前只内置 2026、2027 年官方安排；其他年份仍按每周工作日规则计算。

## 开源与贡献

本项目使用 MIT License。欢迎提交 Issue 和 Pull Request。
