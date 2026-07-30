# 文章指标首页布局优化

## 完成内容

- 首页文章指标固定为独立行，不再与 `hint`、来源或其他元数据同排。
- 移除 `ViewThatFits` 的横向拼接方案及中点分隔符。
- 保留两项指标在指标行内并排展示，以及图标与文字 3pt、指标之间 9pt 的紧凑间距。
- 增加指标上方留白：有 `hint` 时为 8pt；无 `hint` 时从标题到指标为 14pt。
- 无指标时继续完全隐藏，不产生空白占位。

## 验证结果

- 完整应用 Swift 源码语法解析通过。
- 完整应用目标 iOS Simulator 类型检查通过。
- 临时模拟器应用重新编译、签名、安装并成功启动。
- 新截图确认标题、来源提示和指标分别位于三个清晰层级，72pt 缩略图与原有列表结构保持不变。

## 产物

- `DailyReader/Features/Home/StoryRowView.swift`
- `docs/design/article-metrics/design-spec.md`
- `docs/design/article-metrics/runtime-baseline/home-after-separate-metrics-row.png`

## 备注

常规 `xcodebuild test` 仍受当前 Xcode 27 Beta 的 SwiftPM 嵌套沙盒问题限制；本次通过完整目标类型检查与真实模拟器运行验证关键路径。
