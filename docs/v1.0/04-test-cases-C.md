# 测试用例 C：《日报阅读器》v1.0

## 0. 说明

当前仓库只有 PRD，尚无 SwiftUI 源码或 Xcode 工程。本测试用例基于 `docs/v1.0/01-product-requirements.md` 和接口文档 `docs/v1.0/03-api-document-B.md` 编写，用于指导后续开发、mock 服务、自动化测试和监工验收。

测试策略采用 XCTest 体系和测试驱动开发（TDD）：

- 白盒测试：由测试 agent 使用 XCTest 编写，覆盖 API 解析、ViewModel 状态机、缓存策略、分享 URL 优先级、去重逻辑；
- 黑盒测试：由测试 agent 使用 XCUITest 编写，覆盖 App 主链路、离线/错误态、分享入口、范围外功能不可见；
- iOS 开发 agent 必须先运行测试 agent 提供的失败测试，再实现代码让测试变绿；
- P0 用例必须自动化优先，无法自动化的系统能力要记录手工替代方案；
- 监控/集成 agent 每轮运行 `xcodebuild test`，监工 agent 最终独立复核测试结果。

优先级：

- P0：主链路或崩溃风险，必须通过；
- P1：核心体验与异常恢复，发布前应通过；
- P2：边界体验、兼容性、性能和回归增强。

## 0.1 XCTest / XCUITest 落地规范

建议测试目录：

```text
DailyReaderTests/
├── HomeViewModelTests.swift
├── ArticleDetailViewModelTests.swift
├── CacheStoreTests.swift
├── ZhihuDailyAPITests.swift
├── SharingPolicyTests.swift
├── MockDailyAPIClient.swift
├── MockURLProtocol.swift
└── TestFixtures/
    ├── latest_success.json
    ├── latest_empty.json
    ├── latest_missing_fields.json
    ├── history_success.json
    ├── detail_success.json
    ├── detail_empty_body.json
    ├── detail_missing_share_url.json
    └── malformed.json

DailyReaderUITests/
├── HomeFlowUITests.swift
├── DetailFlowUITests.swift
├── OfflineFlowUITests.swift
├── SharingFlowUITests.swift
└── ScopeBoundaryUITests.swift
```

测试命名要求：

```swift
func test对象_when条件_then结果()
```

示例：

```swift
func testLoadLatest_whenNetworkSucceeds_thenShowsStoriesAndTopStories()
func testRefresh_whenNetworkFails_thenKeepsExistingStories()
func testLoadDetail_whenBodyIsEmpty_thenShowsUnavailableMessage()
func testShare_whenShareURLMissing_thenDisablesSharing()
func testCache_whenJSONIsCorrupted_thenDoesNotCrash()
func testHomeFlow_whenOfflineWithoutCache_thenShowsRetryError()
```

UI 测试要求：

- 关键控件必须设置 `accessibilityIdentifier`；
- UI 测试不得依赖真实外部接口，必须通过 launch argument 或环境变量切换 mock 场景；
- 示例启动参数：

```text
-UITestMode YES
MOCK_SCENARIO=latest_success
MOCK_SCENARIO=offline_without_cache
MOCK_SCENARIO=offline_with_cache
MOCK_SCENARIO=detail_empty_body
```

建议 identifier：

| 页面 | 元素 | Identifier |
| --- | --- | --- |
| 首页 | 根视图 | `home.screen` |
| 首页 | 加载态 | `home.loading` |
| 首页 | 错误态 | `home.error` |
| 首页 | 重试按钮 | `home.retryButton` |
| 首页 | 顶部故事列表 | `home.topStories` |
| 首页 | 普通列表 | `home.storyList` |
| 首页 | 离线提示 | `home.offlineBanner` |
| 详情 | 根视图 | `detail.screen` |
| 详情 | 加载态 | `detail.loading` |
| 详情 | 错误态 | `detail.error` |
| 详情 | 正文容器 | `detail.webView` |
| 详情 | 不可用文案 | `detail.bodyUnavailable` |
| 详情 | 分享按钮 | `detail.shareButton` |
| 详情 | 缓存提示 | `detail.cacheBanner` |

## 1. 功能测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-FUNC-001 | 首页首次加载 | 设备联网，接口可用，无缓存 | 启动 App | 展示加载态；请求 `GET /news/latest` 成功后展示日期、顶部故事、普通列表 | P0 | UI 自动化 + Mock |
| C-FUNC-002 | 首页数据展示 | latest 返回 `date`、`stories`、`top_stories` | 等待首页加载完成 | 日期、顶部故事横向卡片、普通故事列表均出现 | P0 | UI 自动化 |
| C-FUNC-003 | 顶部故事点击 | 首页有 `top_stories` | 点击顶部故事卡片 | 进入对应文章详情，请求 `/news/{id}` | P0 | UI 自动化 |
| C-FUNC-004 | 普通列表点击 | 首页有 `stories` | 点击普通文章 | 进入对应文章详情 | P0 | UI 自动化 |
| C-FUNC-005 | 详情正常阅读 | 详情返回标题、头图、HTML、分享链接 | 进入详情 | 展示返回、标题、头图、正文、分享按钮 | P0 | UI 自动化 |
| C-FUNC-006 | 返回首页 | 已进入详情 | 点击返回 | 返回首页，首页列表状态保留 | P0 | UI 自动化 |
| C-FUNC-007 | 系统分享 | 详情有有效 `share_url` | 点击分享 | 调起系统分享面板，内容包含标题和链接 | P0 | UI 自动化/手工 |
| C-FUNC-008 | 下拉刷新成功 | 首页已有内容，网络可用 | 下拉刷新 | 保留旧内容；成功后更新数据并写缓存 | P1 | Mock 新旧数据 |
| C-FUNC-009 | 加载历史成功 | 首页已有今日内容 | 滚动到底部 | 请求 `/news/before/{date}`；按日期分组追加历史内容 | P0 | UI 自动化 |
| C-FUNC-010 | 多次加载历史 | 已加载一天历史 | 连续触底 | 每次向前加载更早日报，列表不重复 | P1 | UI 自动化 |
| C-FUNC-011 | 无顶部故事 | `top_stories` 为空或缺失 | 启动 App | 顶部区隐藏，普通列表正常 | P1 | 单元 + UI |
| C-FUNC-012 | 无图文章 | `images` 为空或缺失 | 查看首页 | 标题可读；使用占位或纯文本；仍可点击 | P1 | Snapshot |
| C-FUNC-013 | 标题过长 | 返回长标题 | 查看首页 | 顶部故事标题最多约 2 行，列表不撑破布局 | P1 | Snapshot |
| C-FUNC-014 | 详情无头图 | 详情缺少 `image` | 进入详情 | 头图区隐藏或占位，正文正常 | P1 | UI 自动化 |
| C-FUNC-015 | 详情正文为空 | `body` 为空或缺失 | 进入详情 | 不白屏，显示“文章内容暂不可用” | P0 | UI 自动化 |
| C-FUNC-016 | 分享链接缺失 | 无 `share_url` 且无兜底 URL | 点击分享 | 禁用分享或提示“当前文章暂不可分享” | P0 | UI 自动化 |
| C-FUNC-017 | 外链处理 | HTML 中有外链 | 点击外链 | 外链行为可控，不破坏返回路径 | P1 | 手工 |
| C-FUNC-018 | 不做项检查 | 正常启动 | 检查全局入口 | 不出现登录、注册、评论、点赞、收藏、搜索、主题日报入口 | P1 | UI 文本扫描 |

## 2. 接口与解析测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-API-001 | latest | Mock 正常 JSON | 请求 `/news/latest` | 解析日期、普通故事、顶部故事 | P0 | 单元测试 |
| C-API-002 | before | 日期参数如 `20260621` | 请求 `/news/before/20260621` | 使用 before 语义，返回前一天数据 | P0 | 单元测试 |
| C-API-003 | detail | 有效文章 id | 请求 `/news/{id}` | 解析标题、正文、图片、分享链接 | P0 | 单元测试 |
| C-API-004 | 非 2xx | Mock 403/404/500/502 | 请求 latest/before/detail | 不崩溃；有缓存读缓存；无缓存错误态 | P0 | Mock URLProtocol |
| C-API-005 | 超时 | Mock 请求超时 | 启动或进详情 | 有旧内容则保留，无旧内容显示错误 | P0 | 单元测试 |
| C-API-006 | JSON 破损 | 返回非 JSON 或破损 JSON | 解析响应 | 捕获解析失败，展示错误或缓存兜底 | P0 | 单元测试 |
| C-API-007 | 字段类型变化 | `id`、`images` 类型异常 | 解析响应 | 不崩溃，不可用内容降级 | P1 | Fuzz JSON |
| C-API-008 | stories 为空 | `stories: []` | 加载首页 | 展示空态，不误报网络错误 | P1 | UI 自动化 |
| C-API-009 | top_stories 为空 | `top_stories: []` | 加载首页 | 顶部区隐藏 | P1 | UI 自动化 |
| C-API-010 | 重复文章 id | 今日与历史有重复 id | 加载历史 | 重复文章去重 | P1 | 单元测试 |
| C-API-011 | share_url 优先 | 详情和列表都有 URL | 点击分享 | 优先使用详情 `share_url` | P1 | 单元测试 |
| C-API-012 | 分享兜底 | 详情无 `share_url`，列表有 URL | 点击分享 | 使用列表 URL 兜底 | P1 | 单元测试 |
| C-API-013 | 空标题 | 文章缺标题 | 加载首页 | 不展示为正常可点击文章 | P1 | 单元 + UI |
| C-API-014 | 图片 URL 失效 | 图片地址 404 | 加载首页/详情 | 图片失败不影响文字阅读 | P1 | Mock 图片 |

## 3. UI 与交互测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-UI-001 | 首页加载态 | 接口延迟返回 | 启动 App | 首屏有加载态，不白屏 | P0 | UI 自动化 |
| C-UI-002 | 首页错误态 | 无网络无缓存 | 启动 App | 显示“网络不可用，请检查连接后重试”和重试入口 | P0 | UI 自动化 |
| C-UI-003 | 首页空态 | 接口成功但列表为空 | 启动 App | 展示空态，不显示错误态 | P1 | UI 自动化 |
| C-UI-004 | 重试成功 | 首页错误态，网络恢复 | 点击重试 | 重新请求并展示首页内容 | P0 | UI 自动化 |
| C-UI-005 | 刷新失败提示 | 首页已有内容，刷新失败 | 下拉刷新 | 保留旧内容，提示“刷新失败，已保留上次内容” | P0 | UI 自动化 |
| C-UI-006 | 历史失败提示 | 已有首页内容，before 失败 | 触底加载 | 保留已有内容，底部可重试 | P1 | UI 自动化 |
| C-UI-007 | 顶部横向滚动 | 多个 top stories | 横向滑动 | 可横向滚动，不自动轮播 | P1 | UI/手工 |
| C-UI-008 | 列表纵向滚动 | 多天数据 | 快速滚动 | 滚动顺畅，日期分组清晰 | P1 | 手工 |
| C-UI-009 | 详情加载态 | 详情延迟返回 | 进入详情 | 显示详情加载态，完成后切正文 | P0 | UI 自动化 |
| C-UI-010 | 详情重试 | 详情失败无缓存 | 点击重试 | 恢复网络后可加载正文 | P0 | UI 自动化 |
| C-UI-011 | 首页缓存提示 | 离线且有首页缓存 | 启动 App | 显示“当前离线，正在显示缓存内容” | P0 | UI 自动化 |
| C-UI-012 | 详情缓存提示 | 离线且有详情缓存 | 打开文章 | 显示缓存详情和“正在显示缓存内容” | P0 | UI 自动化 |
| C-UI-013 | 分享取消 | 分享面板已打开 | 取消分享 | 返回详情页，阅读状态不丢失 | P1 | 手工/UI |
| C-UI-014 | 中文文案 | 触发各种状态 | 检查文案 | 无英文裸错误、无技术堆栈 | P1 | UI 文本断言 |
| C-UI-015 | 深色首页 | 系统深色模式 | 启动首页 | 背景、文字、卡片、错误态可读 | P1 | Snapshot |
| C-UI-016 | 深色详情 | 系统深色模式 | 进入详情 | 详情外壳可读，Web 内容无明显不可读 | P1 | Snapshot/手工 |
| C-UI-017 | 动态字体 | 字体调大 | 启动并进入详情 | 关键文案不严重截断，按钮可点击 | P2 | 手工 |
| C-UI-018 | 返回路径 | 首页→详情→分享→取消→返回 | 执行路径 | 导航栈稳定，可回首页 | P0 | UI 自动化 |

## 4. 异常、弱网、空数据测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-ERR-001 | 无网络无首页缓存 | 清空缓存，断网 | 启动 App | 首页错误态，不崩溃不白屏 | P0 | UI 自动化 |
| C-ERR-002 | 无网络有首页缓存 | 先联网加载，杀进程，断网 | 启动 App | 读取最近 30 天缓存，显示离线提示 | P0 | UI 自动化 |
| C-ERR-003 | 无网络有详情缓存 | 先打开详情写缓存，断网 | 打开该文章 | 展示缓存详情 | P0 | UI 自动化 |
| C-ERR-004 | 无网络无详情缓存 | 首页有缓存但详情没打开过 | 断网点击文章 | 展示详情错误态和重试按钮 | P0 | UI 自动化 |
| C-ERR-005 | 弱网首页 | 网络延迟 5-10 秒 | 启动 App | 加载态合理，超时可恢复 | P1 | Network Link Conditioner |
| C-ERR-006 | 弱网图片 | 文本快、图片慢 | 查看首页 | 标题优先可读，图片逐步加载 | P1 | 手工 |
| C-ERR-007 | 刷新失败 | 首页已有内容，刷新 500 | 下拉刷新 | 旧内容保留，失败不覆盖缓存 | P0 | UI 自动化 |
| C-ERR-008 | 历史加载失败 | 首页已有数据，before 失败 | 触底 | 今日列表不受影响 | P1 | UI 自动化 |
| C-ERR-009 | 详情失败有缓存 | 详情已缓存，接口失败 | 点击文章 | 读缓存并提示 | P0 | UI 自动化 |
| C-ERR-010 | 详情失败无缓存 | detail 500，无缓存 | 点击文章 | 中文错误和重试入口 | P0 | UI 自动化 |
| C-ERR-011 | Web 异常 | body HTML 异常 | 进入详情 | 不崩溃、不白屏，有兜底 | P1 | Mock |
| C-ERR-012 | 缓存损坏 | 本地缓存文件损坏 | 启动 App | 捕获失败，尝试网络或展示错误 | P0 | 单元测试 |
| C-ERR-013 | 接口 403/502 | Mock 返回 403/502 | 启动或进详情 | 缓存兜底或错误态，不误展示空态 | P0 | Mock |
| C-ERR-014 | 空图片数组 | `images: []` | 加载首页 | 不越界、不崩溃 | P0 | 单元测试 |
| C-ERR-015 | 大量数据 | 历史返回大量 stories | 加载历史 | 可滚动，内存无明显异常 | P2 | 性能手工 |

## 5. 缓存与图片测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-CACHE-001 | 首页缓存写入 | latest 成功 | 启动并加载首页 | 今日列表写入本地缓存 | P0 | 单元测试 |
| C-CACHE-002 | 历史缓存写入 | before 成功 | 加载历史 | 历史列表写入最近 30 天缓存 | P1 | 单元测试 |
| C-CACHE-003 | 详情缓存写入 | detail 成功 | 进入详情 | 详情写入缓存 | P0 | 单元测试 |
| C-CACHE-004 | 杀进程读取 | 已有首页和详情缓存 | 杀进程断网重启 | 首页和已打开详情可读 | P0 | UI/手工 |
| C-CACHE-005 | 30 天范围 | 已加载超过 30 天 | 检查缓存 | 最近 30 天可用，超范围不作为必保 | P1 | 单元测试 |
| C-CACHE-006 | 网络优先 | 有旧缓存，网络返回新数据 | 启动 App | 优先展示新数据并更新缓存 | P0 | Mock |
| C-CACHE-007 | 失败不覆盖缓存 | 有缓存，网络失败 | 启动或刷新 | 旧缓存仍可用 | P0 | 单元测试 |
| C-CACHE-008 | 缓存状态区分 | 离线读缓存 | 启动 App | UI 明确提示缓存内容 | P0 | UI 自动化 |
| C-CACHE-009 | 图片缓存非强承诺 | 图片曾加载，断网 | 查看首页 | 有则显示，无则不影响标题 | P1 | 手工 |
| C-CACHE-010 | 图片失败占位 | 图片 404/超时 | 查看首页/详情 | 占位或隐藏，文本正常 | P1 | Mock |
| C-CACHE-011 | 图片不卡主线程 | 多张远程图片 | 快速滚动 | 基本流畅，无明显主线程卡顿 | P2 | Instruments |
| C-CACHE-012 | 清空缓存 | 手动清空 App 数据 | 断网启动 | 展示无网络错误态 | P0 | 手工 |

## 6. 兼容性测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-COMP-001 | iOS 17 | iOS 17 模拟器/真机 | 完成主路径 | App 正常运行 | P0 | CI |
| C-COMP-002 | 最新 iOS | 最新稳定 iOS | 首页、详情、分享 | 主链路正常 | P1 | CI/手工 |
| C-COMP-003 | 小屏 iPhone | iPhone SE 尺寸 | 查看首页详情 | 关键内容不遮挡，按钮可点 | P1 | Snapshot |
| C-COMP-004 | 大屏 iPhone | Pro Max 尺寸 | 查看首页详情 | 阅读宽度合理 | P2 | Snapshot |
| C-COMP-005 | 竖屏优先 | iPhone 竖屏 | 完成主路径 | 体验完整 | P0 | UI 自动化 |
| C-COMP-006 | 横屏 | iPhone 横屏 | 旋转设备 | 不要求专属布局，但不能崩溃 | P2 | 手工 |
| C-COMP-007 | iPad | iPad 模拟器 | 启动 App | 不要求专属布局，但基本可用 | P2 | 手工 |
| C-COMP-008 | 深浅切换 | App 运行中切换外观 | 查看首页详情 | UI 跟随系统，文字可读 | P1 | Snapshot |
| C-COMP-009 | 中文环境 | 系统中文 | 触发错误态 | 中文显示正常 | P1 | UI 自动化 |
| C-COMP-010 | 非中文环境 | 系统英文 | 启动 App | v1.0 文案仍中文，无乱码 | P2 | 手工 |
| C-COMP-011 | 后台恢复 | 首页加载成功 | 切后台再回来 | 页面状态保持 | P1 | 手工 |
| C-COMP-012 | 内存压力 | 多次进详情加载图片 | 长时间浏览 | 无明显泄漏，返回正常 | P2 | Instruments |

## 7. 回归测试

| 编号 | 模块 | 前置条件 | 步骤 | 预期结果 | 优先级 | 自动化建议 |
| --- | --- | --- | --- | --- | --- | --- |
| C-REG-001 | 阅读主链路 | 网络正常 | 启动→首页→详情→分享→返回 | 全链路成功，无崩溃 | P0 | 每次构建 |
| C-REG-002 | 离线缓存 | 有首页和详情缓存 | 断网启动→打开详情 | 缓存可读，提示出现 | P0 | UI 自动化 |
| C-REG-003 | 无缓存错误 | 清空缓存，断网 | 启动 App | 首页错误态和重试入口正确 | P0 | UI 自动化 |
| C-REG-004 | 刷新失败 | 首页已有内容 | 下拉刷新失败 | 不清空旧内容 | P0 | UI 自动化 |
| C-REG-005 | 历史加载 | 首页成功 | 触底加载历史 | 内容追加，分组正确，去重 | P1 | UI 自动化 |
| C-REG-006 | 详情异常 | 空 body、无 share_url、无 image | 分别打开详情 | 不白屏，不错误分享 | P0 | 参数化测试 |
| C-REG-007 | 字段变更 | 缺字段/类型异常 JSON | 加载首页详情 | 解析失败可控，不崩溃 | P0 | 单元测试 |
| C-REG-008 | 图片失败 | 图片 404/超时 | 查看首页详情 | 占位/隐藏正确，文字可读 | P1 | UI 自动化 |
| C-REG-009 | 深色模式 | 深色模式 | 截图首页详情错误态 | 样式可读 | P1 | Snapshot |
| C-REG-010 | 不做项 | 正常启动 | 检查全局入口 | 不出现登录、评论、点赞、收藏、搜索等 | P1 | UI 文本扫描 |

## 8. 自动化分层建议

| 层级 | 覆盖内容 |
| --- | --- |
| XCTest 白盒单元测试 | 接口解析、字段缺失、ViewModel 状态转换、缓存读写、分享 URL 优先级、去重逻辑 |
| XCTest 网络 Mock 测试 | latest、before、detail 的 200、403、500、502、超时、破损 JSON |
| XCUITest 黑盒 UI 测试 | 阅读主链路、离线缓存、无缓存错误、刷新失败、分享面板、范围外入口不可见 |
| Snapshot | 首页、详情、错误态、空态、缓存态、深色模式、小屏 |
| 手工测试 | 系统分享真实行为、外链跳转、弱网、WebView 深色模式、Instruments |

## 8.1 TDD 执行顺序

每个功能切片按以下顺序推进：

1. 测试 agent 从本文件选择对应 P0/P1 用例；
2. 测试 agent 编写 XCTest / XCUITest，确认测试因功能未实现而失败；
3. iOS 开发 agent 实现最小功能让测试通过；
4. 测试 agent 增加边界用例；
5. iOS 开发 agent 重构并保持测试绿灯；
6. 监控/集成 agent 运行完整 `xcodebuild test`；
7. 监工 agent 在验收阶段复核测试报告和关键手工场景。

P0 测试准入：

| 能力 | 必须测试 |
| --- | --- |
| 首页加载 | `HomeViewModelTests` + `HomeFlowUITests` |
| 顶部故事点击 | `HomeFlowUITests` |
| 普通文章点击 | `HomeFlowUITests` |
| 详情正常阅读 | `ArticleDetailViewModelTests` + `DetailFlowUITests` |
| 分享 URL 选择 | `SharingPolicyTests` |
| 无网络无缓存 | `HomeViewModelTests` + `OfflineFlowUITests` |
| 无网络有缓存 | `CacheStoreTests` + `OfflineFlowUITests` |
| 详情 body 为空 | `ArticleDetailViewModelTests` + `DetailFlowUITests` |
| 缓存损坏 | `CacheStoreTests` |
| JSON 破损 | `ZhihuDailyAPITests` |

## 8.2 测试 agent 交付物

测试 agent 每轮必须交付：

- 新增或更新的 XCTest / XCUITest 文件列表；
- 覆盖的测试用例编号；
- 当前红灯/绿灯状态；
- 无法自动化的用例及手工替代说明；
- 对开发 agent 的失败测试复现命令。

推荐复现命令：

```text
xcodebuild -project 知乎日报-SwiftUI.xcodeproj -scheme DailyReader -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## 9. 监工验收最小清单

监工 agent 至少要独立验证：

- 首次启动有加载态；
- 今日内容可展示；
- 顶部故事可横向滚动；
- 普通列表可进入详情；
- 详情 HTML 可阅读；
- 分享可调起系统面板；
- 刷新失败保留旧内容；
- 历史加载失败不影响已有列表；
- 无网络有缓存可读；
- 无网络无缓存有错误态；
- 缓存损坏不崩溃；
- 缺正文不白屏；
- 缺分享链接不错误分享；
- 深色模式可读；
- 不出现 v1.0 明确不做项。
