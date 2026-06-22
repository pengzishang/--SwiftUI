# HTTPClient 现有代码调查与 Alamofire 重构方案设计报告

本报告针对项目中的底层网络请求类 `HTTPClient.swift` 进行静态调查，梳理其与其他组件（如 `ZhihuDailyAPI.swift` 和单元测试）之间的调用和依赖关系，并详细设计了将其改写为基于 Alamofire 实现的具体思路。

---

## 1. `HTTPClient.swift` 现有代码及接口调查

通过对 `DailyReader/Networking/HTTPClient.swift` 的分析，目前其核心接口与内部实现如下：

### 1.1 类结构与属性
- **类定义**：`final class HTTPClient`
- **内部属性**：
  - `baseURL: URL`：网络接口的基准地址（缺省为 `https://news-at.zhihu.com/api/4`）。
  - `session: URLSession`：底层的网络会话实例（缺省为 `URLSession.shared`）。
  - `decoder: JSONDecoder`：数据解析器（缺省为 `JSONDecoder()`）。
  - `timeoutInterval: TimeInterval`：超时时间间隔（缺省为 `15` 秒）。

### 1.2 核心方法与错误处理
- **接口定义**：
  ```swift
  func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T
  ```
- **核心逻辑**：
  1. **路径规范化与拼接**：去掉路径前缀的 `/`，并使用 `baseURL.appendingPathComponent` 拼接成完整的 URL。
  2. **请求构建**：通过 `URLRequest(url: url, timeoutInterval: timeoutInterval)` 构建请求，方法设为 `GET`。
  3. **请求头注入**：设置请求头 `Accept: application/json` 和 `User-Agent: DailyReaderSwiftUI/1.0`。
  4. **异步请求**：通过 `session.data(for: request)` 执行。
  5. **响应验证**：
     - 若响应非 `HTTPURLResponse`，抛出 `APIError.invalidResponse`；
     - 若状态码非 200-299，抛出 `APIError.httpStatus(statusCode)`；
  6. **数据解码**：使用 `decoder.decode(T.self, from: data)`，若解码失败，抛出 `APIError.decodingFailed`。
  7. **异常适配**：底层抛出的其他网络异常统一被包装为 `APIError.transport(error.localizedDescription)` 并抛出。

---

## 2. 外部调用与依赖关系调查

`HTTPClient` 在项目中的依赖和使用情况如下：

### 2.1 业务层 `ZhihuDailyAPI.swift` 的依赖
- **实例持有**：作为 `ZhihuDailyAPI` 类的私有属性，在初始化时通过构造器注入（默认值为 `HTTPClient()`）：
  ```swift
  final class ZhihuDailyAPI: DailyAPIClient {
      private let httpClient: HTTPClient
      init(httpClient: HTTPClient = HTTPClient()) {
          self.httpClient = httpClient
      }
      ...
  }
  ```
- **接口调用**：
  - `fetchLatest()`：调用 `httpClient.get("/news/latest")`；
  - `fetchBefore(date:)`：调用 `httpClient.get("/news/before/\(date)")`；
  - `fetchDetail(id:)`：调用 `httpClient.get("/news/\(id)")`。

### 2.2 单元测试 `ZhihuDailyAPITests.swift` 的依赖与网络 mock
为了避免真实的 HTTP 请求影响单元测试，测试套件构建了 Mock 机制：
- **MockURLProtocol**：自定义的 `URLProtocol`，通过 `MockURLProtocol.handler` 拦截和定制请求返回的 `statusCode` 及数据。
- **URLSession 桥接**：
  在 `ZhihuDailyAPITests.swift` 中，测试方法会构建一个 `URLSessionConfiguration.ephemeral`，将 `protocolClasses` 指向 `[MockURLProtocol.self]`，接着用该配置实例化 `URLSession`，并传递给 `HTTPClient` 构造函数：
  ```swift
  let configuration = URLSessionConfiguration.ephemeral
  configuration.protocolClasses = [MockURLProtocol.self]
  let session = URLSession(configuration: configuration)
  let httpClient = HTTPClient(session: session)
  let api = ZhihuDailyAPI(httpClient: httpClient)
  ```
- **请求头断言**：
  测试 `testFetchBeforeUsesBeforePathAndUserAgent` 捕获了发出的 `URLRequest`，并断言其头信息：
  ```swift
  XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Accept"), "application/json")
  XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), "DailyReaderSwiftUI/1.0")
  ```

---

## 3. 基于 Alamofire 的 HTTPClient 重构方案

为了将底层的网络请求替换为 Alamofire，且不破坏现有的接口契约和单元测试 mock 机制，提出如下设计方案：

### 3.1 引入 Alamofire 依赖库 (`project.yml`)
在项目的 `project.yml` 中新增 Swift 包依赖配置：
1. **定义 package**（根级别下）：
   ```yaml
   packages:
     Alamofire:
       url: https://github.com/Alamofire/Alamofire.git
       from: 5.9.1
   ```
2. **在 DailyReader target 的依赖中引用**：
   ```yaml
   targets:
     DailyReader:
       ...
       dependencies:
         - package: Alamofire
   ```

### 3.2 保持 `HTTPClient` 对外契约一致性
对外公共接口保持完全不变，避免修改 `ZhihuDailyAPI` 和单元测试的实例化逻辑：
- `final class HTTPClient` 依旧保留。
- 构造函数签名完全保持一致：
  ```swift
  init(
      baseURL: URL = URL(string: "https://news-at.zhihu.com/api/4")!,
      session: URLSession = .shared,
      decoder: JSONDecoder = JSONDecoder(),
      timeoutInterval: TimeInterval = 15
  )
  ```
- 泛型异步方法 `get` 签名完全保持一致：
  ```swift
  func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T
  ```

### 3.3 解决 `URLSession` 向 Alamofire `Session` 的桥接
外部单元测试中传入的 `URLSession` 带有自定义的 `MockURLProtocol` 配置。由于 Alamofire 的 `Session` 不支持直接包装没有配置 Alamofire 自定义 Delegate 的 `URLSession` 对象，我们需要**提取传入 `URLSession` 的 `configuration`，然后用该 configuration 创建 Alamofire 的 `Session` 实例**。
这不仅能保留 `timeoutInterval`，还会使 configuration 中的 `protocolClasses`（包含 `MockURLProtocol`）完全生效：
```swift
import Foundation
import Alamofire

final class HTTPClient {
    private let baseURL: URL
    private let session: Session // 替换为 Alamofire.Session
    private let decoder: JSONDecoder
    private let timeoutInterval: TimeInterval

    init(
        baseURL: URL = URL(string: "https://news-at.zhihu.com/api/4")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        timeoutInterval: TimeInterval = 15
    ) {
        self.baseURL = baseURL
        self.decoder = decoder
        self.timeoutInterval = timeoutInterval

        // 提取传入 URLSession 的配置以保留 MockURLProtocol 等设置
        let configuration = session.configuration
        configuration.timeoutIntervalForRequest = timeoutInterval
        
        // 使用该配置构建 Alamofire.Session，并配置全局拦截器注入 HTTP 头
        let interceptor = HTTPClientInterceptor(userAgent: HTTPClient.browserUserAgent)
        self.session = Session(configuration: configuration, interceptor: interceptor)
    }
    ...
}
```

### 3.4 合理的浏览器 User-Agent 统一注入设计
为了绕过防爬虫限制，需要将请求头中的 User-Agent 升级为合理的浏览器标识。

#### A. User-Agent 字符串选择
由于本应用为移动端 iOS 应用，推荐注入当前主流的 iOS 移动端 Safari 的 User-Agent 头（或者现代 macOS 上的 Chrome 头）：
- **iOS Safari (推荐)**:
  `Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1`
- **macOS Chrome (备选)**:
  `Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36`

#### B. 统一注入实现：RequestInterceptor
使用 Alamofire 推荐的 `RequestInterceptor` / `RequestAdapter` 协议，统一对 Session 管理的所有请求进行头部拦截修改：
```swift
private struct HTTPClientInterceptor: RequestInterceptor {
    let userAgent: String

    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        completion(.success(request))
    }
}
```
这样，每次通过 `self.session.request` 发送请求时，拦截器都会在底层自动将 `User-Agent` 与 `Accept` 写入 HTTP 请求头，实现了高内聚。

### 3.5 错误适配器设计
为了符合对外的 `APIError` 契约，需要将 Alamofire 的 `AFError` 或底层错误适配映射至原来的枚举：
```swift
private func mapToAPIError(_ error: Error) -> APIError {
    if let afError = error as? AFError {
        switch afError {
        case .responseValidationFailed(let reason):
            if case .unacceptableStatusCode(let code) = reason {
                return .httpStatus(code)
            }
            return .invalidResponse
        case .responseSerializationFailed(let reason):
            return .decodingFailed
        case .sessionTaskFailed(let underlyingError):
            return .transport(underlyingError.localizedDescription)
        default:
            return .transport(afError.localizedDescription)
        }
    } else if let apiError = error as? APIError {
        return apiError
    } else {
        return .transport(error.localizedDescription)
    }
}
```

### 3.6 改写后的 `get` 方法实现细节
利用 Alamofire 提供的 `async/await` 支持以及内置的 `validate` 机制实现：
```swift
func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
    let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
    guard !normalizedPath.isEmpty else {
        throw APIError.invalidURL
    }
    let url = baseURL.appendingPathComponent(normalizedPath)
    
    do {
        let value = try await session.request(url, method: .get)
            .validate(statusCode: 200..<300)
            .serializingDecodable(T.self, decoder: decoder)
            .value
        return value
    } catch {
        throw mapToAPIError(error)
    }
}
```

---

## 4. 单元测试需要进行的调整

由于 `ZhihuDailyAPITests.swift` 中存在以下对 User-Agent 精确匹配的断言：
```swift
XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), "DailyReaderSwiftUI/1.0")
```
在将 User-Agent 修改为真实的浏览器头部后，此测试会因不一致而失败。

### 解决方案
在实施阶段，需要修改 `DailyReaderTests/ZhihuDailyAPITests.swift` 的第 30 行，将预期的 User-Agent 字符串调整为新的浏览器 User-Agent 字符串：
```swift
XCTAssertEqual(
    capturedRequest?.value(forHTTPHeaderField: "User-Agent"), 
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"
)
```
或者，如果不想在测试中硬编码长字符串，可以在 `HTTPClient` 中以静态常量（`static let browserUserAgent = "..."`）暴露此 UA，并在测试中断言：
```swift
XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "User-Agent"), HTTPClient.browserUserAgent)
```
这是一种更灵活且不易出错的验证方案。
