# 1.1 版本开发验收文档 (Walkthrough)

我们已在当前 `antigravity/daily-news-dev` 工作分支上完整开发了 1.1 版本的所有需求，且通过了自动化测试的全面验证，并完成了 Git 提交。

## 主要变更

### 0. 当前导航与版本状态
- 当前 App 内版本显示为 **1.1**。
- 底部主导航为 **4 个 Tab**：日报、收藏、已读、设置。
- “冷宫”作为低频管理入口，已移动到：设置 → 阅读管理 → 冷宫。
- `docs/v1.0` 保留为首版验收归档；当前主线文档以 `docs/v1.1` 为准。

### 1. 数据模型与持久化层
- **[PersistentStories.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Models/PersistentStories.swift)** [MODIFY]：
  - 定义了 `HiddenStory`、`FavoriteStory` 和 `ReadStory` 三个数据结构，保存 `StorySummary` 及 `date` 字段，用于列表的分组渲染。
  - **已读时间戳记录**：为 `ReadStory` 结构新增了 `readAt: Date` 属性，并实现自动向后兼容解码（旧记录解析为当前时间），用于按已读先后顺序进行动态排序。

### 2. 状态与业务逻辑层
- **[HomeViewModel.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeViewModel.swift)** [MODIFY]：
  - 在 `UserDefaults` 中实现序列化加载与持久化保存“冷宫”、“已读”和“收藏”列表。
  - 实现空 Section 自动过滤剔除逻辑（使用 `.filter { !$0.stories.isEmpty }`）。
  - 提供四个计算属性：主页 `visibleSections`、冷宫 `hiddenSections`、收藏 `favoriteSections`，以及新增的已读扁平列表 `visibleReadStories`（自动过滤隐藏项与收藏项，并根据 `readAt` 降序排列，保证最近阅读的放在最前面）。
  - **取消收藏联动首页**：修改了 `toggleFavorite` 逻辑，当用户在收藏页或详情页中选择**取消收藏**时，会自动调用 `restoreStory` 移出冷宫，保证该文章被放回日报首页展示。
  - **已读状态记录更新**：在 `markStoryRead` 及 `toggleRead` 逻辑中，当文章被标记为已读时，会实时追加或更新 `readAt` 为当前系统时间，从而让最新阅读过的文章立刻呈现在已读页最顶端。
  - **严格互斥分流规则**：确保一篇文章只能出现在 4 个 Tab 中其中一个地方。优先级从高到低依次为：**冷宫 > 收藏 > 已读 > 日报首页**。
  - **增量刷新（Diff 级渲染）**：重构了 `refresh` 拉取机制。当下拉刷新时，不再全量清空重载 `sections`，而是进行**增量合并 (Incremental Merge)**。如果新抓取的数据与第一组 Section 日期重合，则增量向前插入新文章；如果是全新日期的文章，则直接在顶部 prepend 新的 Section，而老旧的历史 Section（如昨日、前日）和滚动位置均完好保留，实现平滑流畅的加载动画。
  - **主页完整 Feed 缓存优先与后台 Revalidate**：主页启动 `load()` 时优先从本地读取序列化的完整 `sections` 和 `topStories`（包括历史分页数据）进行秒级渲染展示，接着在后台执行网络请求更新，并在更新成功后自动保存和合并，发生网络异常时保留当前缓存展现并提示离线横幅。

- **[CacheStore.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Storage/CacheStore.swift) / [DiskCacheStore.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Storage/DiskCacheStore.swift)** [MODIFY]：
  - 支持 `saveHomeFeed` 和 `loadHomeFeed` 接口，把主页的所有 sections 完整状态与 topStories 缓存到 `home_feed.json` 磁盘文件中。

- **[ArticleDetailViewModel.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/ArticleDetailViewModel.swift)** [MODIFY]：
  - **已读文章缓存优先 (Cache-First)**：重构了详情页的加载逻辑。如果本地已存在该文章的缓存详情数据，直接加载并呈现在界面上，跳过网络请求，从而实现“秒开”的效果，且避免了网络带宽和时间的重复开销。

### 3. UI 界面与交互重构
- **[AppRootView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/AppRootView.swift)** [MODIFY]：
  - 重整分栏选项，底部 TabBar 精简为 **4 个 Tab 标签栏布局**：日报 (`newspaper`)、收藏 (`star`)、已读 (`checkmark.circle`) 和**设置 (`gearshape`)**。
  - **UI测试隔离**：在 `-UITestMode` 下启动时，会自动清空已读、冷宫、收藏等数据的 UserDefaults 缓存，并且每次启动均清除网络缓存文件夹 `DailyReaderCache`，确保测试在隔离干净、无脏缓存残留的环境下进行。
  - **文章 WebView 预热**：App 进入后延迟触发 `ArticleWebViewPrewarmer`，提前初始化轻量 `WKWebView`，降低第一次进入文章详情时的 WebKit 冷启动顿卡。
- **[SettingsView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/SettingsView.swift)** [MODIFY]：
  - **移入“冷宫”功能**：精简底部主导航后，将原“冷宫”功能页面移入设置页面内，添加了 NavigationLink 入口。
  - **列表字体大小调节**：新增“列表字体大小”调节滑动条，同样使用 5 档刻度，通过 `@AppStorage("DailyReader.listFontSize")` 控制并持久化。
- **[StoryRowView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/StoryRowView.swift)** [MODIFY]：
  - **列表字体动态缩放**：引入 `@AppStorage` listFontSize，使文章列表标题字号动态绑定至 14px~22px，副标题（hint）按比例自适应计算（`max(10, listFontSize - 3)`），提供卓越的视觉体验。
  - **去除已读变暗样式**：去除了已读文章置灰/变暗逻辑，确保全列表视觉的一致性。
- **[HomeView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeView.swift)** [MODIFY]：
  - 列表数据源改为 `visibleSections`，增加左滑“不感兴趣”红色手势。
- **[ColdPalaceView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ColdPalaceView.swift)** [NEW]：
  - 渲染冷宫分组列表，左滑提供绿色的“恢复”按钮操作。
- **[FavoritesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/FavoritesView.swift)** [NEW]：
  - 收藏文章的分组展示，左滑提供灰色的“取消收藏”按钮。
- **[ReadStoriesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ReadStoriesView.swift)** [MODIFY]：
  - **扁平列表与时间排序**：不再按日期 Section 分组，重构为单一的平铺列表并按阅读时间由新到旧排序。
  - **内置搜索功能**：增加了基于 `.searchable` 的搜索栏，支持在已读文章中进行实时不区分大小写的标题搜索，若无结果则展示标准的无匹配 Empty 界面。
- **[ArticleDetailView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/ArticleDetailView.swift)** [MODIFY]：
  - **异步渐进式加载（并行渲染与解耦）**：将大图封面、标题渲染与正文富文本 WebView 渲染全面并行解耦。正文加载阶段引入局部 ProgressView 指示器并在 WebView 渲染完成后优雅淡入显示。
  - **封面大图秒开与无缝过渡**：`PlaceholderImageView` 支持传入缩略图 URL。加载高解析大图期间，直接显示已缓存的缩略图做平稳背景占位，大图下载完成后直接浮现覆盖，消除了灰色 placeholder 框的闪烁。
  - **TabBar 自动隐藏**：在进入详情页时自动隐藏底部分栏，返回时恢复。
  - **动态导航标题**：导航栏标题自适应为文章实际标题。
  - **正文插图全屏与缩放**：点击正文插图唤起全屏大图预览 `FullScreenImageViewer`，基于 `UIScrollView` 实现完美的原生双指平滑缩放、双击还原及回弹效果。
  - **紧凑布局**：将文章标题与 HTML WebView 正文采用更紧密的 `VStack(spacing: 6)` 进行编排，减少了大标题与作者用户名框框之间的空白间距。
  - **已读状态菜单限制**：非已读页面中右上角菜单只显示“设为已读”；已读页面中右上角菜单显示“设为未读”以将文章移除出已读列表。
- **[HTMLWebView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/HTMLWebView.swift)** [MODIFY]：
  - **文章引用样式优化**：新增了对 `blockquote` 标签的 CSS 渲染，为文章内部的作者引用/回复区域加上极简优雅的灰色左侧竖边框（`border-left: 3px solid #8E8E93`）与灰色文字，完美对齐知乎日报原生效果。
  - **间距微调**：将正文顶端作者名框框 (`.meta`) 的 top margin 从 `10px` 调整为 `2px`，进一步收窄视觉缝隙。
  - **渲染 key 优化**：`updateUIView` 不再重复拼接完整 HTML，也不再用整段 HTML 字符串作为 reload key，改用轻量 `ContentKey` 判断是否需要重新加载。
  - 监听并应用全局阅读字体大小 `fontSize`。
  - 将“查看知乎讨论”按钮 CSS 样式重写为满宽且具有 `12px` 圆角。

- **[ArticleWebViewPrewarmer.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/ArticleWebViewPrewarmer.swift)** [NEW]：
  - 在首页进入后空闲时预热一个极简 `WKWebView`，把 WebKit 首次初始化成本从“第一次点文章”提前到用户浏览首页阶段。

### 3.1 启动屏与资源
- **[Info.plist](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Resources/Info.plist)** [MODIFY]：
  - 使用 `UILaunchScreen` 配置启动页，替代 deprecated Launch Image。
- **[LaunchBackground.colorset](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Resources/Assets.xcassets/LaunchBackground.colorset)** [NEW]：
  - 提供浅色/深色动态蓝色背景。
- **[LaunchBrandMark.imageset](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Resources/Assets.xcassets/LaunchBrandMark.imageset)** [NEW]：
  - 提供居中的品牌图，包含阅读器图标、中文标题与英文副标。

### 4. 测试与验证层
- **[SettingsTests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderTests/SettingsTests.swift)** [MODIFY]：
  - 针对设置页面的全局字体持久化以及列表字体持久化进行UserDefaults 读写逻辑测试。
- **[HomeViewModelTests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderTests/HomeViewModelTests.swift)** [MODIFY]：
  - 新增互斥分流与列表操作覆盖测试。
- **[ArticleDetailViewModelTests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderTests/ArticleDetailViewModelTests.swift)** [MODIFY]：
  - 适配了缓存优先的详情加载测试，增加对跳过网络请求直接使用本地缓存行为的校验。
- **[HomeFlowUITests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderUITests/HomeFlowUITests.swift)** [MODIFY]：
  - 适配了动态导航标题的元素定位，确保测试的高可用性。

---

## 验证结果 (测试报告)

所有自动化测试用例通过：

```bash
Test Suite 'HomeFlowUITests' passed at 2026-06-22 09:32:48.336.
	 Executed 10 tests, with 1 test skipped and 0 failures (0 unexpected) in 69.665 (69.677) seconds
Test Suite 'DailyReaderUITests.xctest' passed at 2026-06-22 09:32:48.337.
	 Executed 10 tests, with 1 test skipped and 0 failures (0 unexpected) in 69.665 (69.678) seconds
Test Suite 'All tests' passed at 2026-06-22 09:32:48.339.
	 Executed 10 tests, with 1 test skipped and 0 failures (0 unexpected) in 69.665 (69.680) seconds

** TEST SUCCEEDED ** [91.763 sec]
```
