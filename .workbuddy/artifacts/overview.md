# 文章详情双正文系统：实施结果

## 已完成

- 增量 PRD 和文件级架构设计均已完成。
- `qa / article / fallback` 领域契约、显式字段兼容解码与 DOM 分类器已实现。
- 文章详情改为单一可滚动 `WKWebView`：已移除外层正文 `ScrollView`、原生重复标题/题图、WebView 禁滚、JS 测高和 `520pt` 最低高度。
- 已实现版本化结构消息桥、DOM 净化、原标题正常文档流、阅读进度/位置恢复、普通导航标题与“墨迹岛”。
- 已实现无边框 44pt Bar Item、纸面压印反馈、图片 alt 预览、站内路由、安全浏览器和危险 scheme 拒绝。
- 新增分类器、链接路由、阅读状态与短文进度单元测试及三类本地 fixture。

## 验证结果

- `xcodegen generate`：通过。
- 全量 App Swift 类型检查：通过。
- 双正文分类、路由、阅读状态纯逻辑运行检查：通过。
- `git diff --check`：通过。
- 旧 WebView 机制扫描：未发现 `contentHeight`、禁用滚动、`520pt` 测高、Web 链接直接系统打开。

## 尚需补跑

- Xcode 27 Beta 在解析 Alamofire `Package.swift` 时触发嵌套 `sandbox_apply: Operation not permitted`，因此本环境下的 `xcodebuild`、XCTest 与 UI 自动化未进入源码编译阶段。
- 发布前需在非嵌套沙箱环境补跑 Debug build、聚焦单测和真实 WKWebView UI 回归。
- 图片长按保存/复制/分享属于 P1，本轮未伪实现。