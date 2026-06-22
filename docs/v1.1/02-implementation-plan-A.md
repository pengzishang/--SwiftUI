# 实现“冷宫”、“收藏”、“已读”与下拉操作菜单功能 (v1.1)

为了进一步提升用户的阅读管理体验，我们将在 1.1 版本中实现以下功能：
1. 底部分栏扩展为 **5 个 Tab**（日报、冷宫、收藏、已读、设置）。
2. 在不同列表上提供相应的**左滑动作手势**（例如在收藏页左滑可以取消收藏，在已读页左滑可以标记为未读）。
3. 将文章详情页右上角的分享按钮改为 **下拉操作菜单（Menu）**，收纳分享、收藏、已读状态切换等操作。
4. **根据来源 Tab 差异化菜单选项**：从不同 Tab 进入详情页时，三个点菜单所呈现的选项会有所调整。
5. **“查看知乎讨论”按钮样式优化**：将原本的胶囊按钮改为填满宽度（左右留基本边距）、高度 44px 且圆角为 12px 的圆角矩形样式。
6. **空 Section 自动过滤隐藏**：如果某个日期下没有任何文章，该日期的 Section 头部将不会显示在对应的 Tab 列表中。该规则对所有列表均适用。
7. **正文插图点击放大全屏**：文章详情 HTML 正文中的插图支持点击进入全屏大图预览模式，支持双指 Pinch-to-Zoom 缩放以及双击缩放。
8. **进入详情页隐藏 TabBar**：从任意列表页点击文章进入详情页时，底部的 TabBar 将自动隐藏；返回列表页时恢复显示。
9. **详情页导航栏标题自适应**：文章详情页顶部的导航栏标题由“文章详情”修改为显示具体文章的标题。
10. **“设置”页面与字体大小调节**：新增第 5 个“设置” Tab（齿轮图标），提供一个包含 5 档刻度调节（14px、16px、18px、20px、22px）的字体大小 Slider，实时应用到文章详情的阅读排版中。

## 用户审核要求

> [!NOTE]
> 主界面和各子页面的列表都支持左滑（`.swipeActions(edge: .trailing)`）来进行操作，符合 iOS 的交互习惯。
> 详情页右上角的菜单采用系统标准的 `ellipsis.circle` 圆圈三个点图标。
> 详情页在 Push 展现时使用 `.toolbar(.hidden, for: .tabBar)` 自动隐藏 TabBar，返回时无缝展现。
> 字体大小通过 `@AppStorage` 全局持久化并利用 CSS 即时注入 `HTMLWebView` 中实现字体缩放。

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
  - 设为已读（移除设为未读）
  - 不感兴趣（移入冷宫）
- **从“冷宫”打开 (`.coldPalace`)**：
  - 分享
  - 恢复到日报（代替“不感兴趣”）
  - 收藏 / 取消收藏
  - 设为已读
- **从“收藏”打开 (`.favorites`)**：
  - 分享
  - 取消收藏（代替“收藏”，且取消收藏会自动将文章恢复到日报主页）
  - 设为已读
  - 不感兴趣（移入冷宫）
- **从“已读”打开 (`.read`)**：
  - 分享
  - 设为未读（代替“设为已读”）
  - 收藏 / 取消收藏
  - 不感兴趣（移入冷宫）

### 3. “查看知乎讨论”按钮 CSS 调整
修改 `HTMLWebView.swift` 中针对 `a.discussion-pill` 样式的注入，使其扩展为通栏圆角按钮，样式为 `display: flex !important; width: calc(100% - 16px) !important; margin: 20px 8px 8px 8px !important; border-radius: 12px !important;`。

### 4. 正文图片点击与全屏放大
- **HTML 交互注入**：在 `HTMLWebView` 内部利用 JavaScript 监听所有非头像/非作者的 `<img>` 标签的点击事件，在点击时通过 `window.webkit.messageHandlers.imageClicked.postMessage(img.src)` 通知原生侧。
- **原生全屏层**：`ArticleDetailView` 注册图片点击回调后激活状态，以 `.fullScreenCover` 弹出全屏图片浏览器（`FullScreenImageViewer`），带有 MagnificationGesture 手势提供 Pinch-to-Zoom 缩放，并支持双击缩放。

### 5. 字体调节设计
- 存储：使用 `@AppStorage("DailyReader.fontSize")` 记录默认值 `16.0`。
- 设置页：利用 `Slider(value: $fontSize, in: 14...22, step: 2)` 提供 5 个刻度档（14px, 16px, 18px, 20px, 22px）。
- 视图应用：`HTMLWebView` 接收 `fontSize` 变量，通过拼接 HTML 头部 `<style>` 中的 `body { font-size: \(fontSize)px !important; }`，从而实时渲染新字体大小。

### 6. 数据模型与持久化
在 `UserDefaults` 中使用 JSON 序列化持久存储以下数据：
- **`HiddenStory`** (ID, StorySummary, Date) -> 保存到 `DailyReader.hiddenStories`
- **`FavoriteStory`** (ID, StorySummary, Date) -> 保存到 `DailyReader.favoriteStories`
- **`ReadStory`** (ID, StorySummary, Date) -> 保存到 `DailyReader.readStories`

### 7. ViewModel 逻辑排他分流 (`HomeViewModel`)
在 `HomeViewModel` 中管理上述持久化数据的读写，并暴露以下计算属性和方法：
- **过滤属性（满足严格一文一 Tab 的排他机制，优先级：冷宫 > 收藏 > 已读 > 日报）**：
  - `visibleSections`：过滤掉冷宫、收藏、已读后的主页日报列表。
  - `hiddenSections`：冷宫文章分组列表。
  - `favoriteSections`：收藏文章分组列表（自动过滤隐藏项）。
  - `readSections`：已读文章分组列表（自动过滤隐藏项与收藏项）。

---

## 拟更改文件

### [Component: Data & Models]

#### [NEW] [PersistentStories.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Models/PersistentStories.swift)
定义 `HiddenStory`、`FavoriteStory`、`ReadStory` 数据模型，支持 `Codable`。

### [Component: Home & Tab Features]

#### [MODIFY] [HomeViewModel.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeViewModel.swift)
- 增加已隐藏、已收藏、已读列表的状态管理及本地读写逻辑。
- 增加状态切换与联动。
- 提供四个排他性分组计算属性。

#### [MODIFY] [HomeView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/HomeView.swift)
- 切换数据源，增加左滑“不感兴趣”手势。

#### [NEW] [ColdPalaceView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ColdPalaceView.swift)
- 渲染冷宫分组列表，支持左滑“恢复”手势。

#### [NEW] [FavoritesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/FavoritesView.swift)
- 渲染收藏分组列表，支持左滑“取消收藏”手势。

#### [NEW] [ReadStoriesView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/ReadStoriesView.swift)
- 渲染已读分组列表，支持左滑“标记为未读”手势。

#### [NEW] [SettingsView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Home/SettingsView.swift)
- 编写设置页面，包含 5 档刻度字体 Slider 调节。

### [Component: Article Detail]

#### [MODIFY] [ArticleDetailView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/ArticleDetailView.swift)
- 接入 `HomeViewModel` 并接收 `source` 参数。
- 将右上角分享按钮改造为根据 `source` 进行差异化渲染的 `Menu`。
- 实现 `.fullScreenCover` 展现全屏图片浏览器。
- 设置 `.toolbar(.hidden, for: .tabBar)` 隐藏底部 Tab 栏。
- 将 `.navigationTitle` 改为自适应显示文章标题。

#### [MODIFY] [HTMLWebView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/Features/Detail/HTMLWebView.swift)
- 更新 CSS 中的 `a.discussion-pill` 部分，实现满宽 12px 圆角。
- 支持接收 `fontSize` 变量并动态注入 CSS。
- 支持 JS 监听图片点击并传递给 Native 侧。

### [Component: App Root]

#### [MODIFY] [AppRootView.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReader/AppRootView.swift)
- 引入 `TabView` 布局，并把 5 个子 View 放入 NavigationStack 内。

### [Component: Tests]

#### [MODIFY] [HomeViewModelTests.swift](file:///Users/pengzishang/Current%20Project/知乎日报-SwiftUI/DailyReaderTests/HomeViewModelTests.swift)
- 编写完整的隐藏、收藏、已读状态切换与本地持久化的单元测试。
- 编写互斥分流完整流转生命周期测试。

---

## 验证计划

### 自动化测试
运行所有单元测试及 UI 测试，确保其能编译通过并正常运行。
- `xcodebuild -scheme DailyReader -destination "id=F6C7D4D7-8D2E-4D54-9E8D-2595759F69FF" test`

### 手动验证
- **Tab 切换与隐藏**：
  - 点击“日报”文章左滑“不感兴趣”，确认其移入“冷宫”。
  - 进入“冷宫”，左滑“恢复”，确认其返回“日报”。
- **详情页图片与标题验证**：
  - 打开文章详情，验证 Navigation Bar 标题变为具体文章的标题；底部的 Tab Bar 是否已隐藏。
  - 点击正文中的插图，确认能放大全屏，并可用双指进行缩放或双击缩放。关闭全屏返回详情。
- **字体大小调节验证**：
  - 进入“设置” Tab，将字体调节拖拽至最右侧（22px），随后进入日报文章详情页，确认正文字体已变大。
  - 再次回到“设置”，调节至最左侧（14px），确认正文字体相应变小。
- **互斥及已读 Tab 自动隐藏变暗测试**：
  - 日报点击阅读后返回，确认文章从“日报”移入“已读” Tab；并且文章列表的文字标题均没有任何置灰变淡的 dim 逻辑。
