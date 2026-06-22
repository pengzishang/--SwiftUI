## 2026-06-22T22:45:34Z
你被派发为 M1 里程碑的 Worker，执行实施与代码改写任务。
你的工作目录是 `/Users/pengzishang/Current Project/知乎日报-SwiftUI/.agents/worker_m1`。

请按照以下说明工作：
1. **网络层集成依赖**：
   - 修改项目根目录下的 `project.yml` 引入 Alamofire 依赖（版本范围为 >= 5.9.0 且 < 6.0.0）。
   - 在 `DailyReader` 目标的 `dependencies` 下引入包 `Alamofire`。
   - 在项目根目录下运行 `xcodegen` 重新生成 Xcode 工程文件。

2. **HTTPClient.swift 代码改写**：
   - 将 `DailyReader/Networking/HTTPClient.swift` 改写为基于 Alamofire 的实现。
   - 必须保持 `HTTPClient` 类的公共接口与 `get` 方法签名与原先完全一致，不破坏外部对 `HTTPClient` 的调用契约。
   - 为了兼容单元测试 of Mock 机制，构造器中应该能够提取传入 `URLSession` 的 `configuration`，并用其创建 Alamofire 的 `Session` 实例。这可以确保 `MockURLProtocol` 被正确注册并在 Alamofire 中生效。
   - 在请求头中配置统一且合理的 iOS Safari 浏览器 User-Agent，例如：`Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1`。
   - 可以在 `HTTPClient` 里暴露一个 `static let browserUserAgent` 来存放这个 User-Agent。
   - 在底层的请求拦截器中，统一为所有 GET 请求加上 "User-Agent" 和 "Accept" (值为 "application/json") 请求头。
   - 将 Alamofire 抛出的各种错误映射 to 原有的 `APIError` 枚举错误契约中。

3. **单元测试与分支管理**：
   - 检查当前 Git 工作分支，确保其有 `antigravity/` 前缀（例如切换到 `antigravity/m1-alamofire` 分支，如果当前分支不符合，则切换/新建符合的前缀分支）。
   - 修改 `DailyReaderTests/ZhihuDailyAPITests.swift` 中对应的 User-Agent 精确断言，让其等于 `HTTPClient.browserUserAgent`。
   - 运行单元测试验证改动是否成功。编译命令和测试命令为：
     `xcodebuild test -project 知乎日报-SwiftUI.xcodeproj -scheme DailyReader -destination "platform=iOS Simulator,name=iPhone 17" -only-testing:DailyReaderTests`
   - 确保全部 40 个单元测试通过。如果报错，请继续修复，直至完全通过。
   - 每次代码改动并通过验证后，按照 AGENTS.md 规则进行 Git Commit。

4. **产出要求**：
   - 本次开发产生的所有文档、进度报告、日志、任务列表以及代码注释均必须使用中文撰写。
   - 任务完成后，在 `/Users/pengzishang/Current Project/知乎日报-SwiftUI/.agents/worker_m1/handoff.md` 写入交接报告，说明修改的文件、测试结果、Git Commit 提交信息以及任何需要注意的地方。
   - 完成后，通过 `send_message` 向 parent 汇报。
