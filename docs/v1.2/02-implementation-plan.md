# v1.2 实现设计说明：网络底层迁移、热榜引入与“我的”页面合并

本文档记录 v1.2 版本的详细技术设计与实现说明。

---

## 1. 依赖与网络层重构

### 1.1 Alamofire 集成
- **工程配置**：
  在 `project.yml` 中新增 Swift Package Manager 声明并在 target 依赖中添加：
  ```yaml
  packages:
    Alamofire:
      url: https://github.com/Alamofire/Alamofire
      from: 5.9.0
  ```
  集成后需在项目根目录运行 `xcodegen`（如环境已配置）或在 Xcode 中解析 SPM 依赖包。

### 1.2 HTTPClient 改写
- 将原 `DailyReader/Networking/HTTPClient.swift` 替换为基于 Alamofire 的实现。
- 使用 `AF.request` 并链式调用 `.serializingDecodable(T.self)` 序列化解码响应对象。
- 在 `HTTPClient` 请求中注入以下标准 `User-Agent`，确保热榜等知乎内部接口不被服务器识别为机器人请求而拦截：
  ```swift
  let headers: HTTPHeaders = [
      "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
      "Accept": "application/json"
  ]
  ```

### 1.3 接口模型扩展
- **ZhihuDailyAPI 扩展**：
  - 新增 `fetchHotList()` 接口，请求：`https://www.zhihu.com/api/v3/feed/topstory/hot-lists/total?limit=50`
  - 新增 `fetchAnswers(questionID: Int)` 接口，请求：`https://www.zhihu.com/api/v4/questions/\(questionID)/answers?include=content,excerpt,voteup_count,comment_count,author&limit=20`

---

## 2. 知乎热榜模块设计 (Hot List)

### 2.1 数据模型
- 在 `DailyReader/Models/HotListModels.swift` 中定义：
  - `HotListResponse`：外层包裹结构，包含 `data: [HotItem]`。
  - `HotItem`：单个热榜项，包含 `target: HotTarget` 和 `detail_text: String` (如“5000 万热度”)。
  - `HotTarget`：热榜具体问题，包含 `id: Int`、`title: String`、`excerpt: String`。
  - `AnswersResponse`：回答列表响应包裹结构，包含 `data: [AnswerItem]`。
  - `AnswerItem`：单个回答，包含 `id: Int`、`author: AnswerAuthor`、`content: String` (HTML)、`excerpt: String` (摘要)、`voteup_count: Int`。
  - `AnswerAuthor`：回答作者，包含 `name: String` 和 `avatar_url: String`。

### 2.2 视图层设计
- **热榜页 (HotListView)**：
  - 使用 `List` 或 `LazyVStack` 展示排行。排名 1、2、3 名采用红色、橙色、黄色数字标记，4 名及以后使用灰色。
  - 点击每一项通过 `NavigationLink` 跳转到回答列表页。
- **回答列表页 (QuestionAnswersView)**：
  - 顶部以大字号显示问题的 Title。
  - 列表展示前 20 条回答的摘要信息，显示作者昵称、头像（使用异步图片组件缓存）、赞同数和简介片段。
- **回答详情页 (AnswerDetailView)**：
  - 内部持有 `HTMLWebView` 实例，将 `AnswerItem.content` (HTML 字符串) 传递进去进行渲染。

---

## 3. “我的”页面与胶囊切换栏设计 (Unified Me Tab)

### 3.1 导航结构调整
- 重构 `DailyReader/AppRootView.swift` 中的 `TabView`：
  - Tab 1：`HomeView`
  - Tab 2：`HotListView`
  - Tab 3：`MeView` (取代原 `FavoritesView` 和 `ReadStoriesView`)
  - Tab 4：`SettingsView`

### 3.2 药丸胶囊滑块切换栏实现
- 在 `MeView.swift` 顶部自定义切换栏：
  - 用 `HStack` 放置两个 `Button`（“收藏”与“已读”）。
  - 使用 `@Namespace private var animation` 声明一个共享命名空间。
  - 使用 `.matchedGeometryEffect(id: "activeTab", in: animation)` 将半透明胶囊背景（具有微毛玻璃或圆角深灰效果）绑定在当前选中 Tab 按钮的背后。
  - 当状态切换时，SwiftUI 会自动为胶囊背景产生一段极为平滑的横向滑动过渡动画。

### 3.3 搜索与列表交互
- 在切换栏下方增加一个统一的 `TextField` 作为搜索框，绑定一个 `@State var searchText: String`。
- 如果当前选中是“收藏” Tab，将过滤后的 `favoriteSections` 传递给子列表渲染；如果选中是“已读” Tab，则传递过滤后的 `visibleReadStories` 渲染。

---

## 4. 验证与测试规范

1. **编译验证**：
   - 依赖解析完毕后，运行 Xcode 进行真机/模拟器编译，排除任何 Swift 编译器 Warning 与 Error。
2. **接口正确性测试**：
   - 验证 Alamofire 的 `HTTPClient` 能够正确在主线程和后台任务中解析日报及热榜的 JSON。
3. **切换动画与性能走查**：
   - 在“我的”页面快速切换“收藏”与“已读”，确认滑块移动流畅，无闪烁、错位。
