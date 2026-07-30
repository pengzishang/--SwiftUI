# 《日报阅读器》产品需求文档 v1.2

## 0. 文档信息

| 项目 | 内容 |
| --- | --- |
| 产品名称 | 日报阅读器 |
| 产品版本 | v1.2 |
| 目标平台 | iOS 17+ |
| 技术方向 | SwiftUI + WebKit + Alamofire + Swift Testing |
| 数据源 | 知乎日报接口 `https://news-at.zhihu.com/api/4` & 知乎热榜接口 `https://www.zhihu.com/api/v3` |
| 当前定位 | 学习作品集，不代表知乎官方产品 |

## 1. 版本目标

v1.2 主要聚焦于**网络层重构**、**知乎热榜功能引入**、**个人数据整合与导航优化**、**防卸载数据丢失 (Keychain)** 以及**测试架构升级 (Swift Testing)**。
核心目标包括：
1. **网络底层迁移**：网络模块改用行业标准异步库 **Alamofire** 进行底层 HTTP 请求管理。
2. **热榜浏览**：新增独立“热榜” Tab，支持展示知乎实时热门问题 Top 50，并能点击查看回答预览及阅读完整回答正文。
3. **“我的”个人页面重构**：将原“收藏” Tab 和“已读” Tab 合并为一个统一的“我的” Tab。顶部采用自定义的**药丸胶囊背景滑动切换栏**进行平滑无缝切换。
4. **统一搜索**：在“我的”页面提供单搜索框，自动根据当前激活的子 Tab（收藏 / 已读）实时过滤对应列表数据。
5. **卸载重装数据不丢失**：本地阅读历史、收藏和冷宫记录不仅存储于沙盒，还会静默双向同步至系统 **Keychain (钥匙串)**，确保 App 被删除并重新安装后数据可以被自动找回。
6. **测试架构升级**：将目前的单元测试架构全面迁移到 Swift 6 官方的 **Swift Testing** 框架，而 UI 测试由于官方系统限制继续沿用 **XCTest** 框架。

---

## 2. 信息架构

```text
日报阅读器
├── 日报 Tab (HomeView)
│   ├── 顶部故事
│   ├── 日报列表
│   └── 历史分页
├── 热榜 Tab (HotListView) (NEW)
│   └── 热点问题列表 (Top 50)
│       └── 回答列表页 (QuestionAnswersView) (NEW)
│           └── 回答详情页 (AnswerDetailView) (NEW)
├── 我的 Tab (MeView) (NEW)
│   ├── 顶部药丸胶囊滑块切换栏 (收藏 / 已读)
│   ├── 统一搜索框
│   └── 子列表 (FavoritesView / ReadStoriesView)
└── 设置 Tab (SettingsView)
    └── 字体大小/冷宫管理/缓存清理
```

---

## 3. 功能范围

### 3.1 网络底层迁移 (Alamofire Migration)

- 底层网络调用类 `HTTPClient` 改用 **Alamofire** (基于 Swift Concurrency `async/await` 接口)。
- 在请求头中配置统一的浏览器 `User-Agent`，解决防爬与鉴权拦截。

### 3.2 热榜与回答详情 (Hot List & Answers)

- **热榜列表 (HotListView)**：
  - **接口**：`GET https://www.zhihu.com/api/v3/feed/topstory/hot-lists/total?limit=50`
  - **展示规则**：左侧显示排行数字（1-3 红色、橙色、黄色高亮，其余深灰色）。右侧显示标题和热度数据。
  - **分页与刷新**：不支持分页加载更多，仅固定展示前 50 条。支持下拉刷新和加载失败时展示“加载失败”提示与“重试”按钮。
- **回答列表页 (QuestionAnswersView)**：
  - **接口**：`GET https://www.zhihu.com/api/v4/questions/{id}/answers?limit=20`
  - **展示规则**：顶部显示问题标题。列表包含前 20 条精选回答预览，展示作者头像、昵称、摘要和点赞数。
  - **分页与刷新**：仅展示前 20 条，不支持加载下一页，仅支持下拉刷新。
- **回答详情页 (AnswerDetailView)**：
  - **渲染规则**：使用现有的 `HTMLWebView` 对回答的完整 HTML 正文进行全宽渲染。

### 3.3 “我的”个人页面重构 (Consolidated Profile View)

- **导航合并**：TabBar 调整为 4 Tab：日报、热榜、我的、设置。
- **药丸胶囊滑块切换栏**：在“我的”页面顶部设计水平切换栏，使用 SwiftUI 的 `@Namespace` 和 `.matchedGeometryEffect` 实现药丸形半透明胶囊背景平移动效。
- **极简无头像布局**：页面顶部采用大导航标题“我的”，直接衔接胶囊切换栏，不保留任何个人头像或名称。
- **统一搜索**：切换栏正下方提供一个输入搜索框，根据当前选择的子 Tab 动态过滤收藏或已读列表。

### 3.4 防卸载数据丢失 (iCloud 替代方案)

- **Keychain 备份与恢复**：
  - 本地收藏 (`favoriteStoriesKey`)、已读列表 (`readStoriesKey`)、已读 ID (`readStoryIDsKey`)、冷宫列表 (`hiddenStoriesKey`) 在写入 `UserDefaults` 时，会自动将其对应的 JSON 数据和数组加密备份到系统 Keychain（使用特定 Identifier）。
  - 当 App 被卸载并重装后，本地 `UserDefaults` 变为空，App 启动时检测到此状态后会自动从 Keychain 中读取数据，反序列化后还原至 `UserDefaults` 和本地状态中，实现**静默无缝找回**。

---

## 4. 测试与验证标准

1. **测试架构升级 (Swift Testing & XCTest)**：
   - 将 `DailyReaderTests` 目录下的所有测试类和方法由 `XCTest` 重构为 `Swift Testing` (使用 `import Testing`、`@Test` 和 `#expect` 等现代宏)。
   - `DailyReaderUITests` 目录下的 UI 自动化测试保持使用 `XCTest` (使用 `XCUIApplication` 模拟用户交互)。
2. **测试与覆盖率**：
   - 必须为本地数据从 Keychain 恢复、Zhihu API 的 JSON 解码、HomeViewModel 列表过滤逻辑编写完整的单元测试。
   - 编写 UI 单元测试自动执行打开 App、点击热榜、切换“我的”页面选项等流程。
