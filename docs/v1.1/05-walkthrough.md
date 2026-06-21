# 1.1 版本开发验收文档 (Walkthrough)

我们已在当前 `antigravity/daily-news-dev` 工作分支上完整开发了 1.1 版本的所有需求，且通过了自动化测试的全面验证，并完成了 Git 提交。

## 主要变更

### 1. 数据模型与持久化层
- **[PersistentStories.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Models/PersistentStories.swift)** [NEW]：
  - 定义了 `HiddenStory`、`FavoriteStory` 和 `ReadStory` 三个数据结构，保存 `StorySummary` 及 `date` 字段，用于列表的分组渲染。
  - 支持 `Codable`。

### 2. 状态与业务逻辑层
- **[HomeViewModel.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeViewModel.swift)** [MODIFY]：
  - 在 `UserDefaults` 中实现序列化加载与持久化保存“冷宫”、“已读”和“收藏”列表。
  - 实现空 Section 自动过滤剔除逻辑（使用 `.filter { !$0.stories.isEmpty }`）。
  - 提供 `visibleSections`（主页）、`hiddenSections`（冷宫）、`favoriteSections`（收藏）、`readSections`（已读）四个计算属性，自动关联响应。
  - 增加 `hideStory`、`restoreStory`、`toggleFavorite`、`toggleRead` 等多维度交互方法。
  - **取消收藏联动首页**：修改了 `toggleFavorite` 逻辑，当用户在收藏页或详情页中选择**取消收藏**时，会自动调用 `restoreStory` 移出冷宫，保证该文章被放回日报首页展示。

### 3. UI 界面与交互重构
- **[AppRootView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/AppRootView.swift)** [MODIFY]：
  - 引入 `TabView` 并配置 4 个 NavigationStack 标签栏页面（日报 `newspaper`、冷宫 `snowflake`、收藏 `star`、已读 `checkmark.circle`）。
- **[HomeView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeView.swift)** [MODIFY]：
  - 列表数据源改为 `visibleSections`，增加左滑“不感兴趣”红色手势。
- **[ColdPalaceView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ColdPalaceView.swift)** [NEW]：
  - 渲染冷宫分组列表，左滑提供绿色的“恢复”按钮操作。
- **[FavoritesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/FavoritesView.swift)** [NEW]：
  - 收藏文章的分组展示，左滑提供灰色的“取消收藏”按钮（点击后取消收藏并放回首页）。
- **[ReadStoriesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ReadStoriesView.swift)** [NEW]：
  - 展示已读文章，左滑提供橘色的“设为未读”按钮。
- **[ArticleDetailView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/ArticleDetailView.swift)** [MODIFY]：
  - 增加 `source` (enum `ArticleDetailSource`) 及 `date` 参数，以便区分从哪个 Tab 打开该页面。
  - 右上角分享改为自适应的 `Menu`（图标 `ellipsis.circle`），根据来源及状态，动态展现“分享”、“（取消）收藏”、“设为已读”及“不感兴趣/恢复”选项。
  - **已读状态菜单限制**：响应“去掉设为未读”的调整，在日报首页、冷宫及收藏打开的文章详情页中，三个点菜单**不再显示“设为未读”**，仅显示“设为已读”选项。只有在已读 Tab 打开的文章详情页中，才允许显示“设为未读”以将文章移出已读列表。
- **[HTMLWebView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/HTMLWebView.swift)** [MODIFY]：
  - 将“查看知乎讨论”按钮 CSS 样式重写为满宽且具有 `12px` 圆角。

### 4. 测试与验证层
- **[HomeViewModelTests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderTests/HomeViewModelTests.swift)** [MODIFY]：
  - 新增测试：`testHideAndRestoreStory`、`testFavoriteStoryToggle`、`testReadStoryToggleAndSync`、`testPersistenceAcrossInstances`。
  - 新增取消收藏联动测试：`testUnfavoriteAutomaticallyUnhides`，验证在取消收藏后自动触发还原首页（移出冷宫）功能。
- **[HomeFlowUITests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderUITests/HomeFlowUITests.swift)** [MODIFY]：
  - 适配详情页下拉菜单 Menu，支持先点击“操作”再进行按钮禁用的断言。
  - 移除锁定在 1.0 的“收藏”为禁用词，以支持底部分栏。

---

## 验证结果 (测试报告)

所有测试用例已全面通过：

```bash
Test Suite 'HomeFlowUITests' passed at 2026-06-22 01:20:45.942.
	 Executed 10 tests, with 1 test skipped and 0 failures (0 unexpected) in 73.452 (73.471) seconds
Test Suite 'DailyReaderUITests.xctest' passed at 2026-06-22 01:20:45.943.
	 Executed 10 tests, with 1 test skipped and 0 failures (0 unexpected) in 73.452 (73.472) seconds
Test Suite 'All tests' passed at 2026-06-22 01:20:45.944.
	 Executed 10 tests, with 1 test skipped and 0 failures (0 unexpected) in 73.452 (73.474) seconds

** TEST SUCCEEDED **
```
