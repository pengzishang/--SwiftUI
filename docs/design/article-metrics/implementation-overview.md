# 文章互动数据试做概览

## 已完成

- 在 `feature/article-metrics-ui` 实现首页与文章详情的异步互动数据展示。
- 首页仅在日报主列表显示“热度 / 评论”，保留原有标题、来源提示、72pt 缩略图和列表结构；收藏、已读、冷宫等复用列表不会额外发起指标请求。
- 详情在现有来源/日期与 `RuleLine()` 之间显示“日报数据”和“原回答”，两类数据不聚合、不混淆。
- 原回答仅在正文映射到唯一有效 Zhihu answer 时请求；多回答或无有效映射时隐藏。
- 指标失败、为空或不可用时静默隐藏；请求使用 `.reloadIgnoringLocalCacheData`，Repository 不读写指标缓存。
- 加入 VoiceOver 合并标签、稳定无障碍标识、响应式换行和等宽数字。

## 验证结果

- `xcodegen generate` 通过，新 Swift 文件已加入应用 Target。
- 全量 Swift 源码语法解析通过。
- 应用 Target 针对 iOS Simulator 完整类型检查通过，包含 SwiftUI 宏、Alamofire 与 Kingfisher。
- 在真实 iOS 27 模拟器运行并检查：
  - 首页完整指标状态。
  - 详情完整指标状态。
  - 详情指标不可用状态（整组隐藏）。
  - 深色模式 + accessibility-extra-large 字号（来源与数值自然换行）。
- `git diff --check` 通过。

## 已知限制

- Xcode 27 Beta 在解析 Alamofire/Kingfisher 的 `Package.swift` 时触发嵌套 `sandbox-exec: sandbox_apply: Operation not permitted`，常规 `xcodebuild` 和测试运行在项目源码编译前被阻塞。
- 因此本次用已锁定依赖的本地 checkout 关闭嵌套子进程沙盒，完成依赖构建、应用完整类型检查与临时模拟器 App 运行；没有修改项目的生产构建配置。
- 单元测试与 UI 测试源码已补充，但正式测试执行需待 Xcode/SwiftPM 沙盒环境恢复。
