# 薪资时钟项目开发规范

本文件是本仓库后续所有开发任务的强制项目约定。开始修改代码前先阅读本文件，并结合相关源码确认现有行为；完成修改时逐项自检。除非用户明确要求，不得因实现新需求而删除、覆盖或重置工作区内已有改动。

## 1. 功能覆盖：悬浮窗与桌面组件必须同步

- 所有新增或修改的用户可见功能，默认必须同时覆盖 **macOS 悬浮窗（Floating Widget）** 和 **WidgetKit 桌面组件（Desktop Widget）**，不能只在其中一个入口可用。
- 共享业务逻辑、配置字段、统计口径和展示状态应尽可能复用，避免悬浮窗与 Widget 出现结果不一致。
- 涉及进度、金额、家庭成员、隐私、主题、显示开关、时间状态等能力时，必须检查本人视图、家庭成员视图、紧凑/展开悬浮状态，以及小/中/大/超大 Widget 中适用的布局。
- 如果某项能力在某一端确实不适用或受 WidgetKit 系统限制，必须说明原因、记录在 README 和操作手册中，并提供合理的一致性降级方式；不能默默遗漏。
- 新增设置开关时，确认它实际影响悬浮窗和 Widget 的显示或计算，不允许出现“设置可开关但某个端不生效”的情况。

## 2. 所有可编辑数据都必须支持键盘直接输入

- 时间、日期、金额、数量、百分比、分钟数、缴费基数、比例等可编辑数据，必须提供直接键盘输入方式。
- 不得把 Picker、Stepper、滑块或连续点击加减按钮作为唯一输入方式。它们可以作为辅助交互，但必须同时提供可直接编辑的输入控件。
- 时间输入应允许直接输入小时和分钟；日期时间字段应提供可键盘编辑的字段样式或等效输入方式。
- 数值输入必须设置合理范围、精度和格式；提交/失焦时校验并限制非法值，给出清晰反馈。不能因临时输入空字符串或中间态而意外覆盖有效配置。
- 金额等较大数字的输入和展示应正确处理千位分隔符；不要把逗号误判为小数分隔符或导致输入无法解析。
- 分类、主题等有限枚举仍可使用 Picker；本规则针对用户需要输入的数值和时间数据。

## 3. 全局数字展示规范

- 金额、薪资、税费、累计值、数量、百分比等适用数值统一使用千位分隔符，例如 `12,345.67`。
- 主程序、悬浮窗、家庭成员卡片、桌面 Widget、设置摘要和愿望清单应复用统一格式化工具，禁止各页面自行拼接不同格式。
- 日期、时钟、时长、版本号、电话号码等具有专用语义的字符串不套用千位分隔符。
- 新增数字展示时检查隐私遮罩、精度设置、正负数和大数值边界。

## 4. 设置界面信息层级

- 左侧设置导航只显示分类名称，不显示解释性小字；右侧设置卡片和单项不重复展示小字副标题。
- 复杂计算口径、开关影响、适用范围和限制通过对应设置项旁的「？」帮助说明；帮助内容必须准确、完整、简洁，不要给每个简单选项都添加帮助按钮。
- 设置分类应按用户任务组织。主显示内容、金额/百分比精度、进度条和统计展示统一归入「桌面显示」，薪资与家庭仅管理人员薪资、工作日、工作时间和税后计算。
- 调整分类或设置路径时，必须同步修订应用内操作手册、README 和独立操作手册中的路径。

## 4. 视觉与交互一致性

- 新增可视化样式、布局或交互时，优先建设可复用 SwiftUI 组件；悬浮窗和 Widget 共用组件或共用明确的样式/计算实现。
- 不要在不同页面复制多套近似实现；同一类进度条、金额、时间输入应有统一规范。
- 设置修改应遵循现有自动保存机制；有默认值、开关依赖或隐藏字段时，明确处理关闭状态、旧配置迁移和重新开启后的行为。
- 保持现有 macOS 视觉语言、主题、隐私模式、无障碍标签和不同尺寸布局，不为单一页面引入不一致的视觉系统。

## 5. 文档必须与代码同一变更同步

任何新增、删除或修改用户可见功能、设置、默认值、输入方式、计算口径、支持范围或交互步骤时，必须在同一任务中更新：

1. `README.md`：项目功能、适用范围、关键计算/行为和项目结构说明。
2. `Sources/SalaryClock/SettingsView.swift`：应用内「操作手册」对应条目、搜索关键词、操作步骤和示例。
3. `CHANGELOG.md`：当前版本的新增、优化或修复记录；不得擅自修改版本号。
4. 如涉及 Widget、构建、安装或开发流程，同时更新 `docs/` 中相关说明。

文档必须描述实际实现，不得把计划中的功能写成已完成；检查设置入口名称、默认状态、适用端、限制、示例和异常行为。README 中的维护约定也应保持有效。

## 6. 验证与交付

- 业务计算变更：补充或更新 `scripts/check-calculator.swift` 回归测试，覆盖正常、边界、关闭开关、旧配置迁移等情况。
- UI/交互变更：至少确认主程序和 Widget Extension 均能编译；有条件时进行真实界面检查，不得把“编译通过”描述为“视觉验收通过”。
- 运行 `git diff --check`，检查千位分隔格式、键盘输入、悬浮窗/Widget 功能覆盖和文档同步。
- 正式安装前备份现有 app；安装后检查签名、Bundle ID、版本和实际运行路径。
- 不得擅自提交或推送 Git，不得擅自修改版本号、清理用户数据、删除旧备份或重置用户已有改动。

## 7. 主要入口

- `Sources/SalaryClock/FloatingWidgetView.swift`：macOS 悬浮窗。
- `WidgetExtension/SalaryClockWidget.swift`：WidgetKit 桌面组件。
- `Sources/SalaryClock/SettingsView.swift`：设置和应用内操作手册。
- `Sources/SalaryClock/SalaryCalculator.swift`：配置模型与薪资计算。
- `Sources/SalaryClock/SalaryClockModel.swift`：状态、持久化和业务协调。
- `Sources/SalaryClock/NumericFormatting.swift`：统一数值格式化。
- `Sources/SalaryClock/SalaryProgressBar.swift`：统一进度条组件。
- `Sources/SalaryClock/EffectiveWorkSettingsSection.swift`、`Sources/SalaryClock/WorkBreakRecord.swift`：有效工时与休息记录。
- `README.md`、`CHANGELOG.md`、`docs/`：项目说明、版本记录和开发文档。

## 8. 标准构建命令

```bash
./scripts/build-xcode.sh
```

计算逻辑回归检查（包含统一数字格式化）：

```bash
swiftc -parse-as-library Sources/SalaryClock/SalaryCalculator.swift Sources/SalaryClock/WorkBreakRecord.swift Sources/SalaryClock/NumericFormatting.swift scripts/check-calculator.swift -o /tmp/salary-clock-calculator-check
/tmp/salary-clock-calculator-check
```
