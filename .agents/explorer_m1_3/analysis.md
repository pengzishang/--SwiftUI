# 单元测试与网络层测试调查报告

本报告对项目 `DailyReaderTests/` 目录下的现有单元测试进行了系统调查，重点关注与网络层（`HTTPClient`、`DailyAPIClient`）相关的测试文件和实现逻辑，并提供了在当前机器上编译运行这些单元测试的具体命令及执行状态。

---

## 一、单元测试结构调查

`DailyReaderTests` 共包含 5 个测试文件以及相关的 Mock 基础设施和 JSON 数据源（Fixtures）。网络层相关的测试和 Mock 实现分布如下：

### 1. 网络层核心测试文件

*   **`ZhihuDailyAPITests.swift`**
    *   **职责**：这是针对网络层最核心的单元测试文件。它对实现了 `DailyAPIClient` 协议的 `ZhihuDailyAPI` 以及底层的 `HTTPClient` 进行了直接测试。
    *   **测试方法**：通过使用系统内置的 `URLSessionConfiguration.ephemeral`，并注册自定义的 `MockURLProtocol`，拦截所有发出的 HTTP 请求，避免产生真实的网络 IO。
    *   **测试用例**：
        1.  `testFetchLatestParsesStoriesAndTopStories()`: 验证 `fetchLatest()` 方法能正确请求并解析当天日报列表（包含 stories 和 top_stories）。使用 `latest_success.json` 作为 mock 响应。
        2.  `testFetchBeforeUsesBeforePathAndUserAgent()`: 验证调用历史数据接口 `fetchBefore(date:)` 时，网络请求路径是否为 `/api/4/news/before/{date}`，且 HTTP Header 是否包含 `"Accept": "application/json"` 和 `"User-Agent": "DailyReaderSwiftUI/1.0"`。
        3.  `testFetchLatestSkipsBrokenStoryInsteadOfFailingWholeResponse()`: 异常容错测试。验证当日报列表中某一条 Story 格式损坏（使用 `latest_with_broken_story.json`）时，API 客户端能跳过该损坏项，而不是让整个响应解析失败。
        4.  `testFetchDetailParsesShareURL()`: 验证 `fetchDetail(id:)` 详情接口能正确解析 `shareURL`、`url`、图片数组等。使用 `detail_success.json` 进行 mock。
        5.  `testNon2xxThrowsHTTPStatus()`: 验证当服务器返回非 2xx 状态码（如 502）时，API 客户端能正确抛出 `APIError.httpStatus(502)`。
        6.  `testBoundaryHTTPStatusesThrowHTTPStatus()`: 验证在边界状态码（如 403, 404, 500）下，同样抛出对应的 `APIError.httpStatus` 错误。
        7.  `testTimeoutThrowsTransportError()`: 模拟网络超时 `URLError(.timedOut)`，验证客户端抛出包含错误信息的 `APIError.transport` 错误。
        8.  `testMalformedJSONThrowsDecodeError()`: 验证当返回非法 JSON 时，能正确抛出 `APIError.decodingFailed`。

### 2. 网络层 Mock 基础设施

*   **`MockURLProtocol.swift`**
    *   **职责**：继承自 `URLProtocol`，用于拦截网络请求。通过静态变量 `handler` 动态注入 mock 响应（如返回指定状态码和 Data，或者抛出网络异常）。
*   **`MockDailyAPIClient.swift`**
    *   **职责**：实现了 `DailyAPIClient` 协议的 mock 客户端，为 ViewModel 等业务层的测试提供数据存根（Stub）。
    *   它提供静态的 `DailyResponse.fixture`、`DailyResponse.historyFixture` 以及 `ArticleDetail.fixture`，并记录方法调用次数（如 `latestCallCount`、`beforeCallCount`、`detailCallCount`），便于验证调用行为。
    *   **业务测试间接依赖**：`ArticleDetailViewModelTests.swift` 和 `HomeViewModelTests.swift` 利用 `MockDailyAPIClient` 模拟网络层成功/失败等状态，间接测试 ViewModel 在网络响应后的状态流转。

---

## 二、运行测试的具体命令

由于本项目使用了 `project.yml`（XcodeGen）生成 Xcode 工程，项目存在名为 `DailyReader` 的 scheme，其下配置了 `DailyReaderTests`（单元测试）和 `DailyReaderUITests`（UI测试）两个测试 Target。

要在本机（macOS）上通过命令行编译并**仅运行单元测试**（排除较慢且易受环境干扰的 UI 测试），可以使用以下 `xcodebuild` 命令：

```bash
xcodebuild test \
  -project 知乎日报-SwiftUI.xcodeproj \
  -scheme DailyReader \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:DailyReaderTests
```

### 参数说明：
*   `-project 知乎日报-SwiftUI.xcodeproj`: 指定 Xcode 工程文件。
*   `-scheme DailyReader`: 指定构建和测试的 Scheme 名字。
*   `-destination "platform=iOS Simulator,name=iPhone 17"`: 指定测试运行的设备目标。根据当前机器环境，`iPhone 17` (OS 27.0 或 26.5) 模拟器是可用且支持的。
*   `-only-testing:DailyReaderTests`: 关键参数，限制仅执行单元测试 Target，不运行 UI 测试 Target。

---

## 三、当前构建状态和测试状态确认

经在本地环境执行上述测试命令，构建及测试状态如下：

*   **构建状态**：编译顺利通过，无编译报错。
*   **测试执行结果**：全部单元测试用例顺利通过。
*   **具体测试套件执行细节**：
    *   `CacheStoreTests` (缓存层测试): 4 个用例全部通过。
    *   `HomeViewModelTests` (首页 ViewModel 测试): 16 个用例全部通过。
    *   `SettingsTests` (设置项测试): 3 个用例全部通过。
    *   `ZhihuDailyAPITests` (知乎日报网络 API 测试): 8 个用例全部通过。
    *   `ArticleDetailViewModelTests` (文章详情 ViewModel 测试): 9 个用例全部通过。
*   **汇总统计**：
    *   **总执行用例数**: 40 个
    *   **失败用例数**: 0 个
    *   **总耗时**: 约 2.38 秒（从运行到结束共计约 22 秒，包含模拟器启动与编译耗时）
    *   **状态结论**: **TEST SUCCEEDED**
