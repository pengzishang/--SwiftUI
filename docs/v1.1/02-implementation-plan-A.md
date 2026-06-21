# 实现“冷宫”、“收藏”、“已读”与下拉操作菜单功能 (v1.1)

为了进一步提升用户的阅读管理体验，我们将在 1.1 版本中实现以下功能：
1. 底部分栏扩展为 **4 个 Tab**（日报、冷宫、收藏、已读）。
2. 在不同列表上提供相应的**左滑动作手势**（例如在收藏页左滑可以取消收藏，在已读页左滑可以标记为未读）。
3. 将文章详情页右上角的分享按钮改为 **下拉操作菜单（Menu）**，收纳分享、收藏、已读状态切换等操作。
4. **根据来源 Tab 差异化菜单选项**：从不同 Tab 进入详情页时，三个点菜单所呈现的选项会有所调整。
5. **“查看知乎讨论”按钮样式优化**：将原本的胶囊按钮改为填满宽度（左右留基本边距）、高度 44px 且圆角为 12px 的圆角矩形样式。
6. **空 Section 自动过滤隐藏**：如果某个日期下没有任何文章（例如被全部移入冷宫，或者该日期下还没有文章被收藏/已读），该日期的 Section 头部将不会显示在对应的 Tab 列表中。该规则对所有 4 个 Tab 均适用。

## 用户审核要求

> [!NOTE]
> 主界面和各子页面的列表都支持左滑（`.swipeActions(edge: .trailing)`）来进行操作，符合 iOS 的交互习惯。
> 详情页右上角的菜单采用系统标准的 `ellipsis.circle` 圆圈三个点图标。
> 菜单项将根据用户进入文章详情页的来源 Tab 动态变化，避免显示矛盾或无意义的选项（例如已经在冷宫的文章不会再显示“不感兴趣”选项，而是显示“恢复到日报”）。
> 文章底部的“查看知乎讨论”按钮将扩展为宽度铺满容器（减去左右 8px 边距），且圆角统一为 `12px` 以匹配内容图片风格。
> 各个列表将自动过滤掉所有 `stories` 为空的 `DailySection`，确保不会展示只有日期标题却没有内容的空白 Section。

## 方案设计

### 1. 来源标识定义
定义 `ArticleDetailSource` 枚举来标识详情页是从哪个 Tab 打开的：
```swift
enum ArticleDetailSource {
    case daily        // 日报 Tab
    case coldPalace   // 冷宫 Tab
    case favorites    // 收藏 Tab
    case read         // 已读 Tab
}
```

### 2. 下拉菜单的差异化展示逻辑
- **从“日报”打开 (`.daily`)**：
  - 分享
  - 收藏 / 取消收藏
  - 设为未读 / 设为已读
  - 不感兴趣（移入冷宫）
- **从“冷宫”打开 (`.coldPalace`)**：
  - 分享
  - 恢复到日报（代替“不感兴趣”）
  - 收藏 / 取消收藏
  - 设为未读 / 设为已读
- **从“收藏”打开 (`.favorites`)**：
  - 分享
  - 取消收藏（代替“收藏”）
  - 设为未读 / 设为已读
  - 不感兴趣（移入冷宫）
- **从“已读”打开 (`.read`)**：
  - 分享
  - 设为未读（代替“设为已读”）
  - 收藏 / 取消收藏
  - 不感兴趣（移入冷宫）

### 3. “查看知乎讨论”按钮 CSS 调整
修改 `HTMLWebView.swift` 中针对 `a.discussion-pill` 样式的注入，使其扩展为通栏圆角按钮：
```css
a.discussion-pill {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  box-sizing: border-box !important;
  min-height: 44px !important;
  padding: 12px 16px !important;
  margin: 20px 8px 8px 8px !important;
  border-radius: 12px !important;
  background: rgba(10, 132, 255, 0.16) !important;
  color: #0A84FF !important;
  font-weight: 600 !important;
  text-decoration: none !important;
  width: calc(100% - 16px) !important;
}
```

### 4. 数据模型与持久化
在 `UserDefaults` 中使用 JSON 序列化持久存储以下数据：
- **`HiddenStory`** (ID, StorySummary, Date) -> 保存到 `DailyReader.hiddenStories`
- **`FavoriteStory`** (ID, StorySummary, Date) -> 保存到 `DailyReader.favoriteStories`
- **`ReadStory`** (ID, StorySummary, Date) -> 保存到 `DailyReader.readStories`

### 5. ViewModel 逻辑扩展 (`HomeViewModel`)
在 `HomeViewModel` 中管理上述持久化数据的读写，并暴露以下计算属性和方法。注意：所有计算属性都必须通过 `.filter { !$0.stories.isEmpty }` 剔除没有文章的空 Section。
- **过滤属性**：
  - `visibleSections`：过滤掉冷宫文章后的日报列表（主页显示）。
  - `hiddenSections`：冷宫文章按日期分组列表。
  - `favoriteSections`：收藏文章按日期分组列表。
  - `readSections`：已读文章按日期分组列表。
- **状态修改方法**：
  - `hideStory(_ story: StorySummary, date: String)` / `restoreStory(_ storyID: Int)` (冷宫隐藏/恢复)
  - `toggleFavorite(_ story: StorySummary, date: String)` (收藏/取消收藏)
  - `toggleRead(_ story: StorySummary, date: String)` (已读/未读切换)
  - `isStoryFavorited(_ storyID: Int) -> Bool` (判断是否已收藏)

### 6. UI 界面改造
- **AppRootView**: 引入 `TabView`，配置 4 个分栏：
  1. “日报” Tab：图标 `systemName: "newspaper"`
  2. “冷宫” Tab：图标 `systemName: "snowflake"`
  3. “收藏” Tab：图标 `systemName: "star"`
  4. “已读” Tab：图标 `systemName: "checkmark.circle"`
- **HomeView / ColdPalaceView / FavoritesView / ReadStoriesView**: 
  - 渲染对应的 Section 分组。
  - 点击各列表的 cell 时，将对应的 `ArticleDetailSource` 传给 `ArticleDetailView`。
- **ArticleDetailView**:
  - 传入 `homeViewModel: HomeViewModel` 和 `source: ArticleDetailSource`。
  - 右上角 toolbar item 改为 `Menu`，图标为 `ellipsis.circle`，根据 `source` 和当前状态渲染选项。

---

## 拟更改文件

### [Component: Data & Models]

#### [NEW] [PersistentStories.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Models/PersistentStories.swift)
定义 `HiddenStory`、`FavoriteStory`、`ReadStory` 数据模型，支持 `Codable`。

### [Component: Home & Tab Features]

#### [MODIFY] [HomeViewModel.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeViewModel.swift)
- 增加已隐藏、已收藏、已读列表的状态管理及本地读写逻辑。
- 增加状态切换方法。
- 提供四个分组计算属性，并包含空 Section 过滤。

#### [MODIFY] [HomeView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeView.swift)
- 切换数据源，增加左滑“不感兴趣”手势，进入详情页时传入 `.daily`。

#### [NEW] [ColdPalaceView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ColdPalaceView.swift)
- 渲染冷宫分组列表，支持左滑“恢复”手势，进入详情页时传入 `.coldPalace`。

#### [NEW] [FavoritesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/FavoritesView.swift)
- 渲染收藏分组列表，支持左滑“取消收藏”手势，进入详情页时传入 `.favorites`。

#### [NEW] [ReadStoriesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ReadStoriesView.swift)
- 渲染已读分组列表，支持左滑“标记为未读”手势，进入详情页时传入 `.read`。

### [Component: Article Detail]

#### [MODIFY] [ArticleDetailView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/ArticleDetailView.swift)
- 接入 `HomeViewModel` 并接收 `source` 参数。
- 将右上角分享按钮改造为根据 `source` 进行差异化渲染的 `Menu`。

#### [MODIFY] [HTMLWebView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/HTMLWebView.swift)
- 更新 CSS 中的 `a.discussion-pill` 部分，实现满宽 12px 圆角。

### [Component: App Root]

#### [MODIFY] [AppRootView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/AppRootView.swift)
- 引入 `TabView` 布局，并把 4 个子 View 放入 NavigationStack 内。

### [Component: Tests]

#### [MODIFY] [HomeViewModelTests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderTests/HomeViewModelTests.swift)
- 编写完整的隐藏、收藏、已读状态切换与本地持久化的单元测试。

---

## 验证计划

### 自动化测试
运行所有单元测试及 UI 测试，确保其能编译通过并正常运行。
- `xcodebuild -scheme DailyReader -destination "id=F6C7D4D7-8D2E-4D54-9E8D-2595759F69FF" test`

### 手动验证
- **Tab 切换与隐藏**：
  - 点击“日报”文章左滑“不感兴趣”，确认其移入“冷宫”。
  - 进入“冷宫”，左滑“恢复”，确认其返回“日报”。
- **详情页差异化菜单验证**：
  - **在“冷宫”中打开文章**：右上角菜单应**不显示**“不感兴趣”，而是**显示“恢复到日报”**。
  - **在“收藏”中打开文章**：右上角菜单显示“取消收藏”，其他功能保持。
  - **在“已读”中打开文章**：右上角菜单显示“设为未读”，其他功能保持。
- **按钮样式验证**：
  - 打开任一带有知乎讨论的文章，滑动到底部，确认“查看知乎讨论”按钮横向铺满容器（保留基本边距），并且是 12px 圆角。
- **空 Section 过滤验证**：
  - 将某一日期下的所有文章在日报列表左滑“不感兴趣”，返回日报列表，验证该日期的 Section 日期标题是否已自动消失，而不是留下一个空标题。
