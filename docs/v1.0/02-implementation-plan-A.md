# 方案 A：《日报阅读器》v1.0 具体实施方案

## 0. 说明

当前仓库只有产品需求文档 `docs/v1.0/01-product-requirements.md`，尚未包含 SwiftUI 工程、Xcode 项目、模型、网络层或测试代码。

因此本方案是“从 PRD 启动 iOS SwiftUI 开发”的实施方案。它的重点不是修补现有代码，而是把后续开发拆成可以监控、可以多 agent 并行、可以由监工单独验收的工程化流程。

## 1. CRISPE 实施框架

### C = Context：背景

产品目标是实现一个 iOS 17+ 的中文日报阅读 App，核心能力来自 PRD：

- 首页展示今日日报、顶部故事、普通日报列表；
- 支持向前加载历史日报；
- 支持文章详情页阅读 HTML 内容；
- 支持系统分享；
- 支持最近 30 天列表缓存与已打开详情缓存；
- 支持错误态、空态、离线缓存态；
- 深色模式跟随系统；
- 明确不做登录、注册、评论、点赞、搜索、官方品牌复刻、App Store 上架承诺。

接口来源为候选非官方接口：

- `GET https://news-at.zhihu.com/api/4/news/latest`
- `GET https://news-at.zhihu.com/api/4/news/before/{yyyymmdd}`
- `GET https://news-at.zhihu.com/api/4/news/{id}`

接口不是稳定开放契约，所有字段都必须按“可能缺失、为空、类型变化、请求失败”处理。

### R = Request：请求

实施阶段要达成三个协作目标：

1. 监控：持续掌握每个 agent 的进度、改动范围、构建状态、测试状态和阻塞点。
2. 多 agent 并行开发：按模块拆分任务，减少公共文件冲突，让多个 iOS 开发 agent 可以同时推进。
3. 监工单独验证：验证 agent 不参与开发，只从 PRD、接口文档、测试用例和真实构建结果判断是否通过。

推荐角色：

| 角色 | 职责 |
| --- | --- |
| 产品经理 agent | 冻结 v1.0 范围、解释需求边界、维护验收清单 |
| iOS 基础设施 agent | 创建工程、模型、网络、缓存、公共 UI |
| iOS 首页 agent | 首页、顶部故事、列表、历史加载 |
| iOS 详情 agent | 详情页、WebView、分享 |
| 测试/缓存 agent | 基于测试用例 C 编写 XCTest 白盒单元测试、XCUITest 黑盒 UI 测试、Mock 和缓存边界测试 |
| 监控/集成 agent | 监控进度、检查冲突、运行构建和测试、集成改动 |
| 监工验证 agent | 独立验收，不写业务代码 |

### I = Input：输入

实施输入包括：

- PRD：`docs/v1.0/01-product-requirements.md`
- 接口文档：`docs/v1.0/03-api-document-B.md`
- 测试用例：`docs/v1.0/04-test-cases-C.md`
- 平台：iOS 17+
- 技术：SwiftUI + MVVM + async/await + URLSession + WKWebView + XCTest + XCUITest
- 缓存：v1.0 建议先用 JSON 文件缓存，降低 Core Data/SwiftData 并行开发成本

开发模式采用测试驱动开发（TDD）：

```text
测试 agent 根据测试用例 C 先写失败测试
→ iOS 开发 agent 实现最小代码让测试通过
→ 测试 agent 补充边界用例
→ iOS 开发 agent 重构实现
→ 监控/集成 agent 持续运行 build + test
→ 监工 agent 最后独立验收
```

TDD 硬约束：

- P0 功能必须先有 XCTest / XCUITest 覆盖，再进入“完成”状态；
- ViewModel、网络解析、缓存策略必须有白盒单元测试；
- 首页主链路、详情主链路、分享入口、离线错误态必须有黑盒 UI 测试；
- 开发 agent 不能只交互式手测后声称完成；
- 如果某个场景因系统限制无法自动化，必须在测试报告中写明原因和手工替代步骤。

建议工程结构：

```text
知乎日报-SwiftUI.xcodeproj
DailyReader/
├── DailyReaderApp.swift
├── AppRootView.swift
├── Models/
│   ├── StorySummary.swift
│   ├── TopStory.swift
│   ├── DailyResponse.swift
│   ├── ArticleDetail.swift
│   └── ContentSource.swift
├── Networking/
│   ├── DailyAPIClient.swift
│   ├── ZhihuDailyAPI.swift
│   ├── HTTPClient.swift
│   └── APIError.swift
├── Storage/
│   ├── CacheStore.swift
│   ├── DiskCacheStore.swift
│   └── CachePolicy.swift
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   ├── TopStoriesView.swift
│   │   ├── StoryRowView.swift
│   │   └── HomeStateView.swift
│   └── Detail/
│       ├── ArticleDetailView.swift
│       ├── ArticleDetailViewModel.swift
│       ├── HTMLWebView.swift
│       └── ShareSheet.swift
├── Shared/
│   ├── UI/
│   │   ├── LoadingView.swift
│   │   ├── ErrorStateView.swift
│   │   ├── OfflineBanner.swift
│   │   └── PlaceholderImageView.swift
│   └── Extensions/
└── Resources/

DailyReaderTests/
├── HomeViewModelTests.swift
├── ArticleDetailViewModelTests.swift
├── CacheStoreTests.swift
├── ZhihuDailyAPITests.swift
├── MockDailyAPIClient.swift
├── MockURLProtocol.swift
└── TestFixtures/
    ├── latest_success.json
    ├── latest_empty.json
    ├── detail_success.json
    ├── detail_empty_body.json
    └── malformed.json

DailyReaderUITests/
├── HomeFlowUITests.swift
├── DetailFlowUITests.swift
├── OfflineFlowUITests.swift
└── SharingFlowUITests.swift
```

### S = Step：步骤

#### Step 0：冻结范围与验收清单

负责人：产品经理 agent

交付：

- 把 PRD 转成开发任务清单；
- 标注必须做、明确不做、可后置；
- 给每个开发 agent 发边界清晰的任务单。

v1.0 必须做：

- 首页加载今日内容；
- 顶部故事横向卡片，不自动轮播；
- 普通日报列表；
- 历史日报向前加载；
- 文章详情 HTML 阅读；
- 系统分享；
- 最近 30 天列表缓存；
- 已打开详情缓存；
- 网络失败和无缓存错误态；
- 深色模式基本可读。

v1.0 明确不做：

- 登录、注册、评论、点赞、收藏同步、搜索、主题日报、推送、小组件、iPad 专属布局、横屏专属布局、官方品牌复刻。

#### Step 1：创建工程骨架与测试基础设施

负责人：iOS 基础设施 agent + 测试 agent

负责路径：

```text
知乎日报-SwiftUI.xcodeproj
DailyReader/DailyReaderApp.swift
DailyReader/AppRootView.swift
DailyReader/Models/
DailyReader/Networking/
DailyReader/Storage/
DailyReader/Shared/
DailyReaderTests/MockDailyAPIClient.swift
DailyReaderTests/MockURLProtocol.swift
DailyReaderTests/TestFixtures/
DailyReaderUITests/
```

任务：

- 创建 iOS 17+ SwiftUI 工程；
- 建立 MVVM 分层；
- 定义 `DailyAPIClient` 协议；
- 实现 `HTTPClient`、`ZhihuDailyAPI`、`APIError`；
- 定义响应模型，字段尽量可选，解析失败可控；
- 实现 `DiskCacheStore`；
- 提供加载态、错误态、离线提示、占位图等公共 UI。
- 配置 XCTest target 和 XCUITest target；
- 准备 mock fixture、`MockURLProtocol` 和可注入依赖；
- 为 UI 测试提供 launch argument / launch environment，用于切换 mock 场景：

```text
-UITestMode YES
MOCK_SCENARIO=latest_success
MOCK_SCENARIO=offline_with_cache
MOCK_SCENARIO=detail_empty_body
```

验收：

- 工程可 build；
- API 层可 mock；
- 缺字段 JSON 不崩溃；
- 缓存读写失败不崩溃；
- 不引入官方 Logo 和账号体系。
- `xcodebuild test` 可运行；
- 至少有一个失败优先的 XCTest 示例和一个 XCUITest 冒烟示例。

#### Step 1.5：测试 agent 先写 P0 红灯用例

负责人：测试 agent

负责路径：

```text
DailyReaderTests/
DailyReaderUITests/
```

任务：

- 根据测试用例 C 抽取 P0 最小集；
- 先写首页 ViewModel、详情 ViewModel、API 解析、缓存读写测试；
- 再写首页主链路、详情主链路、无网络无缓存、无网络有缓存 UI 测试；
- 所有测试先允许失败，作为开发 agent 的实现目标；
- 每个测试名必须表达业务行为，而不是实现细节。

推荐命名：

```swift
func testLoadLatest_whenNetworkSucceeds_displaysStoriesAndTopStories()
func testRefresh_whenNetworkFails_keepsExistingStories()
func testLoadDetail_whenBodyIsEmpty_showsUnavailableMessage()
func testCache_whenNetworkFails_doesNotOverwriteExistingCache()
func testHomeFlow_whenOfflineWithoutCache_showsRetryError()
```

验收：

- P0 测试用例能编译运行；
- 失败原因指向未实现功能，而不是测试工程配置错误；
- 开发 agent 明确知道每个红灯测试对应哪个实现任务。

#### Step 2：并行开发首页

负责人：首页 iOS agent + 测试 agent

负责路径：

```text
DailyReader/Features/Home/
DailyReaderTests/HomeViewModelTests.swift
```

任务：

- 先阅读并运行首页相关失败测试；
- `HomeView` 与 `HomeViewModel`；
- 今日日期；
- 顶部故事横向卡片；
- 普通故事列表；
- 下拉刷新；
- 历史日报加载；
- 加载态、空态、错误态、离线缓存态；
- 刷新失败保留旧内容；
- 历史加载失败保留已有列表；
- 顶部故事为空时隐藏区域；
- 根据 `id` 去重。
- 每完成一个状态分支，就运行对应 XCTest；
- 首页主路径完成后运行 `HomeFlowUITests`。

验收：

- mock 成功数据能展示首页；
- 缺图文章仍可读、可点；
- 缺标题文章不作为正常可点击文章展示；
- 历史加载按日期分组；
- 深色模式下列表可读。
- 首页相关 P0 XCTest / XCUITest 全部通过。

#### Step 3：并行开发文章详情与分享

负责人：详情 iOS agent + 测试 agent

负责路径：

```text
DailyReader/Features/Detail/
DailyReaderTests/ArticleDetailViewModelTests.swift
```

任务：

- 先阅读并运行详情、分享相关失败测试；
- `ArticleDetailView` 与 `ArticleDetailViewModel`；
- `WKWebView` 封装 `HTMLWebView`；
- 展示标题、头图、HTML 正文；
- 使用系统分享面板；
- 详情失败时读取缓存；
- `body` 为空展示“文章内容暂不可用”；
- 分享链接缺失时禁用分享或提示“当前文章暂不可分享”；
- 外链不破坏返回路径。
- 详情状态机先由 XCTest 覆盖，再补 UI 流程；
- 分享 payload 优先级用单元测试覆盖，系统分享面板用 UI/手工组合验证。

验收：

- 首页可进入详情；
- HTML 正文可阅读；
- 已打开文章断网可回看；
- 缺正文不白屏；
- 缺分享链接不产生错误分享；
- WebView 失败有错误态；
- 详情外壳深色模式可读。
- 详情与分享相关 P0 XCTest / XCUITest 全部通过。

#### Step 4：并行开发缓存与白盒/黑盒测试矩阵

负责人：测试/缓存 agent

负责路径：

```text
DailyReader/Storage/
DailyReaderTests/CacheStoreTests.swift
DailyReaderTests/ZhihuDailyAPITests.swift
DailyReaderTests/MockDailyAPIClient.swift
DailyReaderUITests/
```

任务：

- 最近 30 天列表缓存；
- 已打开详情缓存；
- `ContentSource.network` / `ContentSource.cache` 状态区分；
- 缓存损坏忽略并兜底；
- 网络失败不覆盖可用缓存；
- 构造 mock 场景。
- 编写白盒单元测试：API decode、ViewModel 状态转换、CacheStore 读写/损坏/过期、分享 URL 优先级、历史列表去重；
- 编写黑盒 UI 测试：首页主链路、详情主链路、无网络无缓存、无网络有缓存、刷新失败保留旧内容、分享入口。

关键 mock：

```text
latest 成功
latest 失败 + 有缓存
latest 失败 + 无缓存
before 成功
before 失败但已有列表
detail 成功
detail 失败 + 有缓存
detail 失败 + 无缓存
body 为空
share_url 缺失
图片缺失或 404
缓存 JSON 损坏
```

测试归属：

| 测试类型 | 工具 | 主要文件 | 责任 agent |
| --- | --- | --- | --- |
| 白盒单元测试 | XCTest | `DailyReaderTests/*Tests.swift` | 测试 agent |
| 网络 mock 测试 | XCTest + `URLProtocol` | `ZhihuDailyAPITests.swift`、`MockURLProtocol.swift` | 测试 agent |
| ViewModel 状态测试 | XCTest | `HomeViewModelTests.swift`、`ArticleDetailViewModelTests.swift` | 测试 agent |
| 缓存测试 | XCTest | `CacheStoreTests.swift` | 测试 agent |
| 黑盒 UI 测试 | XCUITest | `DailyReaderUITests/*UITests.swift` | 测试 agent |
| 手工补充验证 | 验收报告 | 分享、外链、弱网、WebView 深色模式 | 测试 agent + 监工 agent |

#### Step 5：监控与集成

负责人：监控/集成 agent

职责：

- 每轮查看 `git status --short`；
- 检查各 agent 是否越界修改；
- 跟踪 build/test 状态；
- 发现公共模型冲突时暂停相关 agent，先合并协议；
- 汇总阻塞点；
- 集成各模块。

建议监控命令：

```text
git status --short
xcodebuild -list
xcodebuild -project 知乎日报-SwiftUI.xcodeproj -scheme DailyReader -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -project 知乎日报-SwiftUI.xcodeproj -scheme DailyReader -destination 'platform=iOS Simulator,name=iPhone 15' test
```

TDD 监控规则：

- 任一 P0 用例红灯时，对应功能不得标记完成；
- 如果开发改动导致已通过测试回归失败，优先修复回归；
- 允许短时间红灯开发，但提交集成前必须恢复绿灯；
- 每个 agent 汇报时必须同时说明“新增/修复了哪些测试”。

监控报告格式：

| 时间 | Agent | 改动路径 | 构建 | 测试 | 风险/阻塞 |
| --- | --- | --- | --- | --- | --- |
| 10:30 | 首页 agent | `Features/Home/` | 通过/失败 | 通过/失败 | 说明 |

#### Step 6：监工单独验证

负责人：监工验证 agent

原则：

- 不写业务代码；
- 不修 bug；
- 不接受开发 agent 自测作为最终结论；
- 只基于 PRD、接口文档、测试用例、构建结果和实际 App 行为验收。

验证流程：

1. 从干净工作区构建；
2. 运行单元测试；
3. 运行 UI 冒烟测试；
4. 手动验证首页、详情、分享、缓存、错误态、深色模式；
5. 检查明确不做项是否误加入；
6. 输出“通过 / 有条件通过 / 不通过”。

### P = Constraint：约束

- 当前仓库尚无 SwiftUI 工程，第一步必须创建工程骨架；
- 所有接口字段都要容错；
- 网络失败不能覆盖可用缓存；
- 刷新失败不能清空旧页面；
- 缓存内容必须可区分于网络内容；
- 不使用知乎官方 Logo；
- 不做官方视觉 1:1 复刻；
- 多 agent 并行时必须按目录隔离；
- 公共模型、协议变更必须经监控/集成 agent 确认；
- 监工 agent 只验证，不参与修复。

### E = Example：任务单示例

首页 agent 任务单：

```text
你是首页 iOS 开发 agent。只负责 DailyReader/Features/Home/ 和 HomeViewModelTests.swift。
基于 PRD v1.0，实现首页：今日日期、顶部故事横向卡片、普通列表、下拉刷新、历史加载、加载态、错误态、离线缓存态。
不得实现登录、搜索、评论、点赞。
完成后运行 HomeViewModelTests，并说明覆盖了哪些异常路径。
```

详情 agent 任务单：

```text
你是详情 iOS 开发 agent。只负责 DailyReader/Features/Detail/ 和 ArticleDetailViewModelTests.swift。
实现文章详情页：标题、头图、HTML 正文、系统分享、加载态、错误态、缓存态。
body 为空时显示“文章内容暂不可用”。
share_url 缺失时不得调起错误分享。
完成后说明 WebView、分享和缓存回退如何验证。
```

监工 agent 任务单：

```text
你是独立监工验证 agent。不要修改业务代码。
请基于 docs/v1.0/01-product-requirements.md、03-api-document-B.md、04-test-cases-C.md 验证 App 是否满足 v1.0。
重点验证：首页、详情、分享、缓存、错误态、离线态、深色模式、不做项。
输出通过/不通过清单，并列出必须修复的问题。
```

## 2. 最终完成定义

方案 A 对应的开发实施阶段视为完成，当且仅当：

- Xcode 工程存在并可构建；
- 首页主路径走通；
- 详情主路径走通；
- 分享主路径走通；
- 无网络有缓存、无网络无缓存、接口失败、缺正文、缺分享链接均有处理；
- 单元测试覆盖 ViewModel、API 解析、缓存损坏；
- UI 冒烟测试覆盖阅读主链路；
- P0 功能均遵循 TDD：先有测试，再有实现，再有绿灯结果；
- 监工 agent 独立验证通过；
- PRD 明确不做项没有进入产品。
