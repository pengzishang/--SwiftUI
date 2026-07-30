# 日报阅读器 2.0

发布日期：2026-07-30
Git Tag：`2.0.0`

## 版本定位

2.0 将日报阅读器从基础新闻阅读器升级为具有编辑化视觉、分层网络架构、文章互动信息和 AI 辅助阅读能力的完整 SwiftUI 阅读产品。应用继续保持“日报 / 热榜 / 我的”三栏结构，不新增独立 AI Tab。

## 核心更新

### AI 阅读助手

- 首页与文章详情均可进入 AI 对话。
- 文章正文支持选择文字，并通过原生菜单“AI 搜索”带入选段。
- 选段只预填、不自动发送；完整文章以不可变上下文快照绑定到 Session。
- 支持多 Session 新建、切换、重命名、删除和重启恢复。
- 支持流式输出、停止生成、重新生成、复制、搜索状态、引用和链接。
- 支持用户自定义 OpenAI 兼容服务，API Key 存入 Keychain。

### 默认 AI 服务竞速

- 一个可见“默认服务”包含 `online`、`sensenova_gou`、`eric` 三条内部线路。
- 每次请求并发启动所有可用 SSE 流。
- 首条产生非空白 `delta.content` 的线路获胜，其他请求立即取消。
- `reasoning_content`、连接状态、工具状态和空白文本不能成为赢家。
- 生产界面不显示内部线路身份或健康比例。
- 内置凭据仅通过 Git 忽略的本地构建配置注入，不提交到仓库。

### 阅读与视觉体验

- 建立“今日刊”纸墨设计系统，覆盖浅色和深色模式。
- 文章详情采用连续 WebView、作者署名栏、首字下沉、阅读进度和回顶控制。
- 支持问答式与文章式正文的统一处理与导航体验。
- 首页和详情页增加文章互动数据展示，并处理加载、无数据和布局稳定性。
- AI 对话导航栏针对 iOS 27 操作胶囊限制标题安全宽度，避免内容覆盖。

### 工程架构

- 网络层采用 Alamofire，图片加载采用 Kingfisher。
- 分离 Transport、Service、Repository、Feature Presentation 等职责。
- 缓存、Keychain、Session 和 Provider 配置均有独立存储边界。
- 单元测试使用 Swift Testing，UI 自动化使用 XCTest。

## 验证摘要

- AI 聚焦测试：24/24 通过。
- 完整单元测试：125/125 通过。
- AI 设置 UI 自动化：2/2 通过。
- Release 模拟器构建通过。
- 真实三线路均能独立产生可见 SSE 正文；竞速能选出唯一赢家并取消其余两条请求。
- 2.0 发布候选已完成最终验证：125/125 单元测试通过、2/2 AI UI 自动化通过、Release 模拟器构建成功，构建产物版本为 `2.0 (2)`，文档引用与敏感信息扫描均通过。

## 配置说明

真实内置服务凭据填写于：

```text
Config/AIProviders.local.xcconfig
```

该文件已被 `.gitignore` 排除。可参考：

```text
Config/AIProviders.payload.json.example
Config/AIProviders.local.xcconfig.example
```

不要将真实 API Key 写入示例文件或提交到 Git。

## 相关文档

- [文档中心](../../README.md)
- [设计系统](../../design/design-system.md)
- [AI 阅读助手 UI 规格](../../design/ai-reading-assistant/ui-design-spec.md)
- [文章互动数据设计](../../design/article-metrics/design-spec.md)
- [双正文系统计划](../../design/article-navigation/dual-system-plan.md)
