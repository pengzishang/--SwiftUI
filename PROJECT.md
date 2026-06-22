# 项目：知乎日报-SwiftUI v1.2

## 架构设计
本项目是一个基于 Model-View-ViewModel (MVVM) 架构模式的 iOS SwiftUI 应用。
- **网络层 (Networking)**：管理与知乎 API 的连接。底层采用 Alamofire 改写 `HTTPClient`，统一请求发送；业务层通过实现 `DailyAPIClient` 协议的 `ZhihuDailyAPI` 和 `LocalFixtureDailyAPIClient` 提供服务。
- **存储层 (Storage)**：使用 `UserDefaults` 和本地磁盘缓存 (`DiskCacheStore`) 管理持久化状态，并引入 `KeychainHelper` 实现收藏/历史/冷宫等核心数据的双写与静默恢复。
- **视图层 (UI - View Layer)**：SwiftUI 视图，分为日报首页（Home）、热榜浏览（Hot List）、统一“我的”个人中心（Me）及设置页（Settings）。
- **测试层 (Testing)**：单元测试目标 `DailyReaderTests` 采用 Swift Testing 框架，UI 测试目标 `DailyReaderUITests` 采用 XCTest 框架。

---

## 里程碑规划

| # | 里程碑名称 | 开发范围描述 | 依赖项 | 当前状态 |
|---|---|---|---|---|
| M1 | Alamofire 迁移 | 更新 `project.yml`，改写 `HTTPClient.swift` 支持 Alamofire，注入浏览器 User-Agent 头部。 | 无 | 进行中 (Conv ID: 200f8823-fb1b-4d20-81dc-4bf0f24aaec8) |
| M2 | 热榜与回答列表 | 创建热榜与回答数据模型，扩展 API 客户端获取 Top 50 热榜，实现热榜列表、回答列表及 Web 详情页渲染。 | M1 | 规划中 (PLANNED) |
| M3 | “我的”页面合并 | TabBar 重构为 4 个。新建 `MeView` 合并收藏和已读，实现药丸胶囊滑块动效与统一搜索过滤。 | M2 | 规划中 (PLANNED) |
| M4 | Keychain 数据备份 | 实现 `KeychainHelper` 模块。在 HomeViewModel 的收藏/历史/冷宫写操作中加入 Keychain 备份，并在 App 启动检测到沙盒为空时恢复。 | 无 | 规划中 (PLANNED) |
| M5 | 单元测试迁移 | 将 `DailyReaderTests` 目录下的所有单元测试文件由 XCTest 改写为 Swift Testing 框架的断言宏与用例。 | 无 | 规划中 (PLANNED) |
| M6 | E2E 与对抗测试 | 接入 E2E 测试套件（Tiers 1-4）确保全通过，并通过 Challenger 机制执行 Tier 5 对抗性覆盖率测试与漏洞加固。 | M1-M5, E2E轨 | 规划中 (PLANNED) |

---

## 接口契约

### API 客户端协议 (`DailyAPIClient`)
```swift
protocol DailyAPIClient {
    func fetchLatest() async throws -> DailyResponse
    func fetchBefore(date: String) async throws -> DailyResponse
    func fetchDetail(id: Int) async throws -> ArticleDetail
    
    // v1.2 新增方法：
    func fetchHotList() async throws -> HotListResponse
    func fetchAnswers(questionID: Int) async throws -> AnswersResponse
}
```

### 钥匙串辅助工具 (`KeychainHelper`)
```swift
final class KeychainHelper {
    static let shared = KeychainHelper()
    
    func save(_ data: Data, forKey key: String) -> Bool
    func read(forKey key: String) -> Data?
    func delete(forKey key: String) -> Bool
}
```
*注：本地持久化同步的键名 (Account Keys)*
- `"DailyReader.readStoryIDs"`
- `"DailyReader.hiddenStories"`
- `"DailyReader.favoriteStories"`
- `"DailyReader.readStories"`

---

## 代码布局
- `DailyReader/Networking/HTTPClient.swift` - 底层网络请求封装。
- `DailyReader/Networking/DailyAPIClient.swift` - API 客户端协议。
- `DailyReader/Networking/ZhihuDailyAPI.swift` - 正式环境 API 实现。
- `DailyReader/Networking/LocalFixtureDailyAPIClient.swift` - UI 自动化与模拟测试 API 实现。
- `DailyReader/Models/HotListModels.swift` - 热榜与回答的数据结构定义。
- `DailyReader/Features/Home/HotListView.swift` - 热榜前 50 条展示页面。
- `DailyReader/Features/Home/QuestionAnswersView.swift` - 热榜问题精选回答列表。
- `DailyReader/Features/Home/AnswerDetailView.swift` - WebKit 渲染的回答正文页。
- `DailyReader/Features/Home/MeView.swift` - 胶囊滑动栏与搜索栏所在的合并个人页。
- `DailyReader/Storage/KeychainHelper.swift` - 原生 Keychain 读写服务。
- `DailyReaderTests/` - 迁移后的 Swift Testing 单元测试代码。
- `DailyReaderUITests/` - XCTest UI 自动化测试代码。
