# AI 文章问答 UI 设计交付概览

## 已完成

- 基于现有 `HomeView`、`ArticleDetailView`、`HTMLWebView`、`MeView`、`SettingsView` 与「今日刊」设计令牌，完成 AI 文章问答和多 Session 功能的完整 UI 规格。
- 逐页定义首页入口、正文选词与悬浮入口、全屏对话页、Session 列表、文章上下文详情和 AI 配置页。
- 覆盖色彩、排版、4pt 间距、组件状态、动效、防重复提交、表单验证、加载/空/错误/离线状态、四档响应式布局及 WCAG 2.1 AA。

## 关键设计决策

- AI 是阅读辅助能力，不新增第四个 Tab；首页入口放导航栏，正文入口放右下悬浮控件组。
- 正文选词阶段菜单与正文同时出现；进入对话后以全屏页面覆盖正文，退出保持阅读位置。
- 新 Session 默认绑定当前文章；旧 Session 不被当前文章静默覆盖，只提供“为当前文章新建对话”或显式替换。
- 手机使用全屏对话 + Session Sheet；≥768pt 使用两栏；≥1200pt 使用 Session / 对话 / 上下文三栏。
- 视觉不引入通用“AI 渐变/发光”风格，严格沿用暖纸、浓墨、靛蓝、宋体和髮丝线。

## 编译核验说明

- XcodeGen 成功生成工程。
- `xcodebuild` 在解析 Alamofire Package 时被 Xcode 27 Beta 的 `sandbox-exec: sandbox_apply: Operation not permitted` 阻断，未进入项目 Swift 源码编译。该限制已在规格文档中明确记录。

## 后续建议

- 开发前先做 iOS 17 `WKWebView` 自定义选词菜单与选区回传技术探针。
- 按“配置与安全存储 → Session 持久化 → 流式对话 → 正文选词/上下文 → 响应式与可访问性”顺序实施。