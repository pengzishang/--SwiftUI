# 《日报阅读器》v1.0 分角色验收 TODO 清单

本文档由 `01-product-requirements.md` 的验收标准与 `05-acceptance-plan-D.md` 的验收角色整理而来，用于开发完成后的分工验收。

角色边界：

- 产品经理 agent：验收需求范围、主路径体验、中文文案与“不做项”。
- iOS 开发 agent：提供可验收构建、解释实现、修复缺陷，不做最终裁判。
- 测试 agent：执行 XCTest / XCUITest / 手工测试，提交测试证据。
- 监控/集成 agent：汇总构建、测试、改动范围、风险和验收材料。
- 监工验收 agent：独立复核最终结果，输出通过 / 有条件通过 / 不通过。

## 1. 产品经理 agent 验收 TODO

### 1.1 主路径与产品体验

- [x] App 启动后可以进入首页。
- [x] 首页在有网络时可以展示今日内容。
- [x] 首页可以展示顶部故事横向卡片。
- [x] 首页可以展示普通日报列表。
- [x] 用户点击顶部故事可以进入文章详情页。
- [x] 用户点击普通日报文章可以进入文章详情页。
- [x] 详情页可以展示并阅读 HTML 正文。
- [x] 用户可以从详情页返回首页。
- [x] 用户可以继续加载历史日报。
- [x] 历史日报按日期分组展示。
- [x] 正常文章可以调起系统分享面板。
- [x] 分享内容包含文章标题。
- [x] 分享内容包含有效文章链接。

### 1.2 异常体验与中文文案

- [x] 无网络且有缓存时，首页提示“当前离线，正在显示缓存内容”。
- [x] 无网络且无缓存时，首页展示错误态和重试入口。
- [x] 下拉刷新失败但有旧内容时，提示“刷新失败，已保留上次内容”。
- [x] 详情失败时有明确中文错误提示。
- [x] 详情请求失败且有缓存时，提示“正在显示缓存内容”。
- [x] `body` 为空时展示“文章内容暂不可用”。
- [x] 分享链接缺失时禁用分享按钮或提示“当前文章暂不可分享”。
- [x] 缺正文、缺图、缺分享链接时均有合理降级体验。

### 1.3 范围边界

- [x] v1.0 不出现登录入口。
- [x] v1.0 不出现评论入口。
- [x] v1.0 不出现点赞入口。
- [x] v1.0 不出现搜索入口。
- [x] v1.0 不出现主题日报入口。
- [x] v1.0 不出现收藏同步能力。
- [x] v1.0 不实现 iPad 专属布局。
- [x] v1.0 不使用官方知乎日报 Logo。
- [x] v1.0 不承诺 App Store 上架。
- [x] v1.0 不实现自动轮播。
- [x] v1.0 不实现日历选择器。
- [x] v1.0 不实现指定日期跳转。
- [x] v1.0 不实现历史搜索。
- [x] v1.0 不批量预加载历史文章。
- [x] v1.0 不实现分享海报。
- [x] v1.0 不实现图片合成。
- [x] v1.0 不接入微信 SDK。
- [x] v1.0 不接入微博 SDK。
- [x] v1.0 不实现自定义分享渠道。

## 2. iOS 开发 agent 准入自检 TODO

### 2.1 构建与运行准入

- [x] 有可运行的 SwiftUI App。
- [x] 提供可复现构建命令。
- [x] 提供指定验收 commit。
- [x] 说明 Xcode 版本、iOS 版本、设备或模拟器信息。
- [x] 验收前无已知 P0 缺陷。
- [x] Mock 或真实接口配置明确。

### 2.2 功能实现自检

- [x] 首页支持加载今日内容。
- [x] 首页支持顶部故事横向卡片。
- [x] 首页支持普通日报列表。
- [x] 首页支持下拉刷新。
- [x] 首页支持加载历史日报。
- [x] 历史加载中显示底部 loading。
- [x] 历史加载失败时保留已有列表。
- [x] 历史加载失败时提供重试入口。
- [x] 接口没有顶部故事时隐藏顶部故事区。
- [x] 隐藏顶部故事区不能影响普通列表展示。
- [x] 顶部故事标题过长时最多显示 2 行。
- [x] 缺失标题的文章不展示为可点击正常文章。
- [x] 历史加载时重复文章需要去重。
- [x] 详情页支持返回、标题、头图、HTML 正文、分享按钮、加载态、错误态、缓存态。
- [x] Web 内容加载失败时展示可恢复错误态。
- [x] 外链打开不能破坏详情页返回路径。

### 2.3 缓存与降级实现自检

- [x] 最近 30 天日报列表可以缓存。
- [x] 用户打开过的文章详情可以缓存。
- [x] 有网络时优先请求网络。
- [x] 请求成功后写入缓存。
- [x] 请求失败时读取缓存。
- [x] 请求失败且无缓存时展示错误态。
- [x] 刷新失败不能清空已有内容。
- [x] 缓存数据需要在 UI 或状态中与实时网络数据区分。
- [x] 杀进程重启后仍能读取首页缓存。
- [x] 杀进程重启后仍能读取已打开文章详情缓存。
- [x] 缓存损坏不导致 App 崩溃。
- [x] 缓存损坏不导致白屏。
- [x] 网络失败不能覆盖可用缓存。
- [x] 图片缓存不作为完整离线阅读承诺。

## 3. 测试 agent 验收 TODO

### 3.1 自动化测试

- [x] XCTest 白盒单元测试可运行。
- [x] XCUITest 黑盒 UI 测试可运行，或有明确手工替代说明。
- [x] 覆盖首页首次加载今日内容。
- [x] 覆盖首页顶部故事展示。
- [x] 覆盖首页普通列表展示。
- [x] 覆盖进入文章详情。
- [x] 覆盖详情 HTML 正文展示。
- [x] 覆盖返回首页。
- [x] 覆盖加载历史日报。
- [x] 覆盖无网络且有缓存时展示缓存内容。
- [x] 覆盖无网络且无缓存时展示错误态。
- [x] 覆盖刷新失败不清空已有内容。
- [x] 覆盖历史加载失败不影响已有列表。
- [x] 覆盖详情失败时有明确中文错误提示。
- [x] 覆盖缺正文时不白屏。
- [x] 覆盖缺分享链接时不分享错误内容。
- [x] 覆盖缓存损坏时不崩溃、不白屏。
- [x] 覆盖网络失败不能覆盖可用缓存。

### 3.2 手工测试

- [x] 手工验证系统分享面板可以调起。
- [x] 手工验证分享内容不能为空。
- [x] 手工验证分享失败不能影响当前阅读。
- [x] 手工验证外链打开后返回路径正常。
- [x] 手工验证弱网或断网缓存表现。
- [x] 手工验证杀进程重启后缓存可读。
- [x] 手工验证首页深色模式可读。
- [x] 手工验证列表卡片深色模式可读。
- [x] 手工验证错误态和空态深色模式可读。
- [x] 手工验证详情页深色模式基本可读。

### 3.3 测试证据

- [x] 保存 XCTest 结果。
- [x] 保存 XCUITest 结果。
- [x] 保存手工测试记录。
- [x] 保存主路径截图或录屏。
- [x] 保存异常路径截图或录屏。
- [x] 列出未执行项及原因。
- [x] 输出缺陷清单，并标注 P0 / P1 / P2。

## 4. 监控/集成 agent 验收 TODO

- [x] 汇总验收 commit。
- [x] 汇总构建命令。
- [x] 汇总构建结果。
- [x] 汇总主要 warning。
- [x] 汇总 XCTest / XCUITest / 手工测试结果。
- [x] 汇总本次改动范围。
- [x] 汇总接口配置、Mock 配置或真实接口配置。
- [x] 汇总仍存在的缺陷。
- [x] 标注是否存在 P0 阻塞问题。
- [x] 标注是否存在 P1 有条件通过风险。
- [x] 检查验收材料是否完整。
- [x] 将截图、录屏、日志和测试报告归档到验收报告目录。

## 5. 监工验收 agent 最终复核 TODO

### 5.1 独立性检查

- [x] 确认监工验收 agent 未参与业务代码开发。
- [x] 确认监工验收 agent 未替开发 agent 修 bug。
- [x] 确认不以“开发自测通过”作为最终依据。
- [x] 确认可运行 App、测试结果和文档均可复查。

### 5.2 准出标准复核

- [x] 所有 P0 用例通过。
- [x] P0 用例已有 XCTest / XCUITest 覆盖，或存在明确手工替代说明。
- [x] 无崩溃。
- [x] 无白屏。
- [x] 无主链路中断。
- [x] 首页主流程可用。
- [x] 详情主流程可用。
- [x] 分享主流程可用。
- [x] 历史加载主流程可用。
- [x] 无网络有缓存时表现正确。
- [x] 无网络无缓存时表现正确。
- [x] 刷新失败不清空旧内容。
- [x] 网络失败不覆盖可用缓存。
- [x] 缺正文、缺图片、缺分享链接均可降级。
- [x] 深色模式基本可读。
- [x] 不做项没有进入产品。
- [x] 验收报告完整。

### 5.3 最终签收

- [x] 产品经理 agent 已确认需求范围和体验符合 PRD。
- [x] 测试 agent 已确认测试执行完成，P0 无阻塞。
- [x] 监工验收 agent 已完成独立复核。
- [x] 输出最终验收结论：通过 / 有条件通过 / 不通过。
- [x] 若为有条件通过，记录 P1 缺陷编号和后续修复计划。
- [x] 若为不通过，记录阻塞项和退回开发原因。

## 6. 角色衍生验收项

### 6.1 产品经理 agent 衍生项

- [x] 下拉刷新失败时，不丢失用户已加载的历史日报分组。
  - 处理结果：`HomeViewModel.refresh()` 失败时保留当前 `sections`，不再用 latest 缓存覆盖已加载历史。
  - 证据：`HomeViewModelTests.testRefreshFailureKeepsLoadedHistorySections`。
- [x] 分享链接必须是可打开的 `http` / `https` 文章链接。
  - 处理结果：`ArticleDetailViewModel.shareURL` 只接受带 host 的 `http` / `https` URL。
  - 证据：`ArticleDetailViewModelTests.testInvalidShareLinkIsRejected`。
- [x] 分享标题应与详情页展示标题一致。
  - 处理结果：新增 `ArticleDetailViewModel.shareTitle`，分享面板使用详情标题，详情标题为空时回退列表标题。
  - 证据：`ArticleDetailViewModelTests.testShareTitleUsesDisplayedDetailTitle`。
- [x] 无网络无缓存错误文案与 PRD 示例保持一致。
  - 处理结果：首页错误文案调整为“网络不可用，请检查连接后重试”。
  - 证据：`HomeViewModelTests.testNetworkFailureWithoutCacheShowsRetryableErrorState`。

### 6.2 测试 agent 衍生项

- [x] 自动化测试覆盖无网络无缓存：首页进入错误态并提供重试入口。
  - 证据：`HomeViewModelTests.testNetworkFailureWithoutCacheShowsRetryableErrorState`。
- [x] 自动化测试覆盖详情失败无缓存：详情进入错误态且不生成分享链接。
  - 证据：`ArticleDetailViewModelTests.testLoadDetailFailureWithoutCacheShowsRetryableError`。
- [x] 自动化测试覆盖缺正文：详情仍进入 loaded 状态，由 UI 展示“文章内容暂不可用”。
  - 证据：`ArticleDetailViewModelTests.testEmptyBodyStillLoadsDetailForUnavailableContentState`。
- [x] 自动化测试覆盖缓存跨实例读取，作为杀进程重启后缓存可读的可重复验证。
  - 证据：`CacheStoreTests.testCachePersistsAcrossStoreInstances`。
- [x] 自动化测试覆盖最近 30 天日报列表缓存保留。
  - 证据：`CacheStoreTests.testDailyListCacheKeepsMostRecentThirtyEntries`。
- [x] XCUITest 覆盖首页、进入详情、返回首页、加载历史日报。
  - 证据：`HomeFlowUITests.testLaunchShowsMockHomeContent`、`testOpenArticleDetailAndReturnHome`、`testLoadHistoryShowsOlderStory`。

### 6.3 监控/集成 agent 衍生项

- [x] 保存正式测试结果路径。
  - 证据：`/Users/pengzishang/Library/Developer/Xcode/DerivedData/知乎日报-SwiftUI-eodslysxiptxuacffaotqhxgmaok/Logs/Test/Test-DailyReader-2026.06.21_14-35-59-+0800.xcresult`。
- [x] 保存亮色首页截图。
  - 证据：`docs/v1.0/acceptance-reports/20260621-acceptance-evidence/home-light.png`。
- [x] 保存深色首页截图。
  - 证据：`docs/v1.0/acceptance-reports/20260621-acceptance-evidence/home-dark.png`。
- [x] 记录构建/测试环境。
  - 证据：Xcode 26.5 / Build 17F42；iPhone 17 Simulator；iOS 26.5。
- [x] 记录测试总数与结论。
  - 证据：`xcodebuild test` 通过，`xcresulttool` 摘要显示 `29/29 passed`。

### 6.4 监工验收 agent 衍生项

- [x] 产品经理 agent 发现的 P1/P2 衍生项已修复并回归测试通过。
- [x] 测试/集成 agent 发现的证据缺口已补充到验收报告和证据目录。
- [x] 最终验收结论改为“通过”，无遗留 P0/P1/P2 阻塞项。

## 7. 清单清空确认

- [x] 本清单中所有原始验收项均已完成。
- [x] 本清单中所有角色衍生验收项均已完成。
- [x] 未保留未勾选 TODO。
