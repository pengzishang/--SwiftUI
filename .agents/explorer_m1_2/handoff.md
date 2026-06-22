# Handoff Report

## 1. Observation
我直接观察并确认了以下内容：
- **`DailyReader/Networking/HTTPClient.swift` 的现有定义**：
  ```swift
  final class HTTPClient {
      private let baseURL: URL
      private let session: URLSession
      private let decoder: JSONDecoder
      private let timeoutInterval: TimeInterval
      
      init(
          baseURL: URL = URL(string: "https://news-at.zhihu.com/api/4")!,
          session: URLSession = .shared,
          decoder: JSONDecoder = JSONDecoder(),
          timeoutInterval: TimeInterval = 15
      )
      
      func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T
  }
  ```
  该类底层依赖原生的 `URLSession`，手动拼接 URL 并设置头部字段 `Accept` 和 `User-Agent: DailyReaderSwiftUI/1.0`（位于 `HTTPClient.swift` 第 29-30 行）。
- **`ZhihuDailyAPI.swift` 对 `HTTPClient` 的依赖**：
  作为私有成员属性被引入，并通过构造函数注入（位于 `ZhihuDailyAPI.swift` 第 4-8 行）。
- **`ZhihuDailyAPITests.swift` 中的单元测试网络 Mock 逻辑**：
  测试通过在 `URLSessionConfiguration.ephemeral` 的 `protocolClasses` 中注册自定义的 `MockURLProtocol.self`（位于第 120, 132 行），进而构造自定义 `URLSession` 传递给 `HTTPClient` 实现网络拦截（位于第 125-127, 136-138 行）。
  测试在 `testFetchBeforeUsesBeforePathAndUserAgent`（第 30 行）中断言：
  ```swift
  XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), "DailyReaderSwiftUI/1.0")
  ```
- **项目结构配置 `project.yml`**：
  不包含 `Alamofire` 依赖项（位于 `project.yml`）。

## 2. Logic Chain
1. **接口兼容性**：为了不破坏现有的对外契约（特别是 `ZhihuDailyAPI.swift` 以及 `ZhihuDailyAPITests.swift` 中的初始化调用），重构后的 `HTTPClient` 必须保持原有的公共类名、初始化参数和 `get` 方法签名。
2. **测试 Mock 兼容性**：测试套件依赖向 `HTTPClient` 注入自定义的 `URLSession`（包含了注册 `MockURLProtocol` 的配置）。若改用 Alamofire，则必须利用传入 `URLSession` 的 `configuration` 来实例化 Alamofire 的 `Session`，否则自定义的 `MockURLProtocol` 无法生效，进而会导致所有 Mock 测试失效或因发起真实网络请求而失败。
3. **User-Agent 注入**：由于知乎接口存在反爬虫限制，必须使用合理的浏览器 User-Agent 头部信息。由于该项目是 iOS 移动端应用程序，使用移动端 Safari 的 User-Agent 头（如 `Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1`）是最合理的设计。
4. **统一头部配置**：为保证代码简洁性，可以使用 Alamofire 的 `RequestInterceptor` / `RequestAdapter` 拦截并注入该头部，使具体请求代码保持纯净。
5. **单元测试维护**：因为修改了 User-Agent，测试中的 User-Agent 精确断言（第 30 行）将无法通过。必须相应地修改测试断言值，或使用 `HTTPClient.browserUserAgent` 静态常量来进行断言。

## 3. Caveats
- 假设宿主环境已经安装并配置好 XcodeGen，重新生成项目文件（`project.yml`）将能正确解析 `Alamofire` 包依赖。
- 未在真实的真机/模拟器网络受限环境下测试知乎服务器对全新 User-Agent 头部的实际拦截表现。

## 4. Conclusion
基于以上逻辑，将 `HTTPClient` 重构为 Alamofire 的方案在技术上完全可行，且能够完全兼容现有的 `DailyAPIClient` 契约和 Mock 测试基础设施。需要进行的具体修改为：
1. 更新 `project.yml` 引入 `Alamofire` 依赖。
2. 改写 `HTTPClient.swift`，在构造器中提取 `URLSession` 的 `configuration` 并利用其初始化 Alamofire 的 `Session`，同时注册 `RequestInterceptor` 注入新的浏览器 User-Agent。
3. 使用 `session.request().validate().serializingDecodable().value` 语法糖改写 `get` 方法，并捕获 `AFError` 进行错误类型适配映射。
4. 将 `ZhihuDailyAPITests.swift` 中的相关断言调整为匹配全新的 User-Agent。

## 5. Verification Method
1. **XcodeGen 项目生成**：
   在工作目录运行 `xcodegen generate`，确保项目文件更新并成功加载 `Alamofire` 依赖包。
2. **构建与运行单元测试**：
   在终端执行以下命令：
   ```bash
   xcodebuild test -project "知乎日报-SwiftUI.xcodeproj" -scheme DailyReader -destination "platform=iOS Simulator,OS=27.0,name=iPhone 17"
   ```
   **注意**：在当前环境的干净分支上，运行上述全量测试可能会遇到 `DailyReaderUITests` 中的 UI 测试因模拟器诊断服务超时（600秒超时）而导致的失败（如 `HomeFlowUITests.testLongBodyCanScrollToTail`）。这属于环境诊断收集超时，并非代码逻辑本身的问题。进行网络层验证时，主要验证 `DailyReaderTests`（单元测试）应全部成功通过，以此证明重构和 User-Agent 的设计没有破坏现有的契约与 Mock 测试。

