# Original User Request

## Initial Request — 2026-06-22T14:29:19Z

# 团队合作项目需求 - 草稿

本项目的目标是开发《日报阅读器》App 的 v1.2 版本，主要包含以下内容：将网络底层替换为 Alamofire，引入知乎热榜与回答列表展示，将“已读”和“收藏”合并为“我的”页面（并使用药丸胶囊背景滑动切换栏与统一搜索框），使用本地系统 Keychain实现防卸载数据丢失，最后将单元测试迁移至最新的 Swift Testing 框架，UI 测试保持使用 XCTest。

工作目录：/Users/pengzishang/Current Project/知乎日报-SwiftUI
诚信模式：demo

## 核心需求

### R1. 底层网络迁移至 Alamofire
- 将 `HTTPClient.swift` 中的原生 `URLSession` 实现改写为使用 Alamofire 库。
- 在请求头中配置统一且合理的浏览器 `User-Agent`，绕过知乎非公开接口的反爬虫限制。
- 更新 `project.yml` 中的依赖，声明引入 Alamofire Swift Package Manager 包。

### R2. 知乎热榜与回答列表功能
- 引入知乎热榜 API（`GET /feed/topstory/hot-lists/total?limit=50`）。
- 列表展示前 50 条热榜问题，左侧数字排名 1-3 名采用红色、橙色、黄色高亮，其余灰色。
- 点击热点项，跳转进入该问题的精选回答列表页（展示前 20 条回答的作者、头像、赞同数和摘要）。点击回答预览，进入独立的“回答详情页”，使用 `HTMLWebView` 渲染完整的回答正文。
- 两级列表均只支持下拉刷新获取固定数量，不支持分页加载更多。

### R3. “我的” Tab 页面合并与胶囊滑块切换栏
- 重构 TabBar 为 4 Tab（日报 / 热榜 / 我的 / 设置）。将原“收藏”与“已读”合并在统一的“我的” Tab 页中。
- 顶部设计自定义的平滑滑动切换栏，采用“药丸胶囊背景滑块”样式，通过 SwiftUI `@Namespace` 共享命名空间和 `.matchedGeometryEffect` 实现胶囊滑块在选项背后的平滑移动。
- 在切换栏正下方添加一个统一的搜索框，根据当前激活的子 Tab（收藏 / 已读）动态过滤当前的列表数据。

### R4. 卸载重装数据不丢失（Keychain 备份）
- 编写 `KeychainHelper` 安全类，基于 iOS 原生 Keychain 钥匙串 API。
- 用户在进行收藏、已读或移入冷宫操作时，除写入本地沙盒 `UserDefaults` 外，自动将最新的数据列表 JSON 序列化并加密写入系统 Keychain。
- 启动 App 时，若检测到本地 `UserDefaults` 均为空（即卸载重装后），则自动从 Keychain 读取数据进行静默无缝恢复。

### R5. 单元测试框架迁移 (Swift Testing)
- 将单元测试目标 `DailyReaderTests` 下的所有单元测试代码由 `XCTest` 重构为最新的 **Swift Testing** 框架（使用 `import Testing`、`@Test`、`#expect` 断言宏）。
- UI 单元测试 (`DailyReaderUITests`) 保持使用 `XCTest` 和 `XCUIApplication`。

## 验收标准 (Acceptance Criteria)

### 编译与构建
- [ ] 项目引入 Alamofire 依赖后编译无报错。
- [ ] 运行 `xcodegen`（如需要）能生成正常的 `.xcodeproj`。

### 功能实现
- [ ] Tab 导航栏正确显示 4 个主 Tab，并且各页面可以无误加载。
- [ ] 知乎热榜成功拉取并展示前 50 条排行，点击热榜能顺利查看回答详情。
- [ ] 我的页面能够进行“收藏”与“已读”的来回切换，且药丸胶囊滑块动效过渡丝滑。
- [ ] 在我的页面输入搜索词，对应的子列表能实时进行过滤搜索.
- [ ] 卸载应用并重新运行编译后，之前的已读和收藏记录能够通过 Keychain 静默恢复。

### 测试验证
- [ ] 单元测试全面采用 Swift Testing 语法并测试通过。
- [ ] UI 单元测试在 XCTest 框架下正常运行并通过。
- [ ] 两个测试目标均能在 Xcode 正常的测试报告中展示结果。

## Follow-up — 2026-06-22T14:36:48Z

Please make sure that all documentation, progress reports, logs, walkthroughs, tasks, and code comments created during this development are written in Chinese. The user explicitly requested all documents to be in Chinese. 请确保本次开发过程中产生的所有文档、进度报告、日志、任务列表以及代码注释均使用中文撰写。
