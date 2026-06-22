# v1.1 实现说明：阅读管理、设置、缓存与性能优化

本文档记录当前 `antigravity/daily-news-dev` 分支上 v1.1 的真实实现状态。早期“5 个 Tab”的方案已调整为当前更简洁的 **4 Tab + 设置内冷宫入口**。

## 1. 导航结构

当前底部 TabBar：

1. 日报：`HomeView`
2. 收藏：`FavoritesView`
3. 已读：`ReadStoriesView`
4. 设置：`SettingsView`

冷宫不是独立 Tab，而是设置页中的 `NavigationLink`：

```text
设置 → 阅读管理 → 冷宫
```

相关文件：

- `DailyReader/AppRootView.swift`
- `DailyReader/Features/Home/HomeView.swift`
- `DailyReader/Features/Home/FavoritesView.swift`
- `DailyReader/Features/Home/ReadStoriesView.swift`
- `DailyReader/Features/Home/SettingsView.swift`
- `DailyReader/Features/Home/ColdPalaceView.swift`

## 2. 本地阅读管理

### 2.1 数据模型

`DailyReader/Models/PersistentStories.swift` 定义：

- `HiddenStory`
- `FavoriteStory`
- `ReadStory`

其中 `ReadStory` 记录 `readAt`，用于已读页按最近阅读时间排序。

### 2.2 状态持久化

`HomeViewModel` 使用 `UserDefaults` 保存：

- `DailyReader.hiddenStories`
- `DailyReader.favoriteStories`
- `DailyReader.readStories`
- `DailyReader.readStoryIDs`

### 2.3 互斥归属

文章归属优先级：

```text
冷宫 > 收藏 > 已读 > 日报
```

对应计算属性：

- `visibleSections`
- `hiddenSections`
- `favoriteSections`
- `visibleReadStories`

已读页当前使用扁平列表，不再按日期 Section 分组。

## 3. 列表与详情交互

### 3.1 左滑操作

- 日报：不感兴趣 → 移入冷宫
- 收藏：取消收藏
- 已读：设为未读
- 冷宫：恢复

### 3.2 详情菜单

`ArticleDetailView` 接收 `ArticleDetailSource`，并按来源决定菜单项：

- 日报、收藏、冷宫入口：默认提供“设为已读”；
- 已读入口：提供“设为未读”；
- 收藏状态决定“收藏 / 取消收藏”；
- 冷宫入口提供“恢复到日报”。

详情页使用：

- `.toolbar(.hidden, for: .tabBar)` 隐藏 TabBar；
- `.navigationTitle(viewModel.shareTitle)` 显示文章标题；
- `.fullScreenCover` 展示正文图片预览。

## 4. 设置与字体

设置页提供两组 5 档字体设置：

- 文章字体大小：`DailyReader.fontSize`
- 列表字体大小：`DailyReader.listFontSize`

文章字体通过 `HTMLWebView` 注入 CSS 生效；列表字体由 `StoryRowView` 绑定 `@AppStorage` 生效。

## 5. HTML 正文渲染

`HTMLWebView` 负责：

- 注入外部 CSS 链接；
- 注入 App 侧阅读样式；
- 改写“查看知乎讨论”为满宽圆角按钮；
- 优化 `.meta`、`.author`、头像和 `blockquote` 样式；
- 监听正文图片点击，通过 `WKScriptMessageHandler` 回调原生侧；
- 外链点击时调用 `UIApplication.shared.open`；
- Web 加载失败或 WebContent 进程终止时回传可恢复错误。

`updateUIView` 已优化：

- 只生成一次完整 HTML；
- 使用轻量 `ContentKey` 判断是否需要重新加载；
- 避免用整段 HTML 字符串作为 reload key。

## 6. 缓存策略

### 6.1 首页完整 Feed 缓存

`CacheStore` 新增：

- `saveHomeFeed(sections:topStories:)`
- `loadHomeFeed()`

`HomeViewModel.load()` 优先读取完整 Feed 缓存并展示，再后台请求最新数据。

### 6.2 历史日报缓存

历史日报成功加载后保存到按业务日期命名的缓存文件。`loadMore()` 网络失败时尝试读取上一日期缓存。

### 6.3 文章详情缓存

`ArticleDetailViewModel.reload()` 先查本地详情缓存；命中后直接展示，不再等待网络。

## 7. 启动屏

使用 `UILaunchScreen`，不使用 deprecated 的 Launch Image。

相关资源：

- `DailyReader/Resources/Info.plist`
- `DailyReader/Resources/Assets.xcassets/LaunchBackground.colorset`
- `DailyReader/Resources/Assets.xcassets/LaunchBrandMark.imageset`

配置项：

- `UIColorName = LaunchBackground`
- `UIImageName = LaunchBrandMark`
- `UIImageRespectsSafeAreaInsets = true`

## 8. 首次文章加载卡顿优化

新增 `ArticleWebViewPrewarmer`：

- AppRootView 出现后延迟 0.7 秒；
- 创建一个 1x1 的轻量 `WKWebView`；
- 加载极简 HTML；
- 保留实例，提前支付 WebKit 首次初始化成本。

这可以削弱用户第一次点击文章时 `WKWebView` 冷启动造成的主线程顿卡。

## 9. 测试与构建

常用构建命令：

```bash
xcodebuild -project 知乎日报-SwiftUI.xcodeproj -scheme DailyReader -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

当前已知非阻塞 warning：

- `All interface orientations must be supported unless the app requires full screen.`

该 warning 与 v1.1 文档整理、启动页和 WebView 性能优化无关。
