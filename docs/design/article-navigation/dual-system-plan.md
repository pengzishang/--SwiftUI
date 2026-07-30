# DailyReader 双正文系统总计划

## 一、最终方向

DailyReader 的文章详情页分为两套内容模板，但共享同一套原生基础能力：

1. **问答式「问答长卷」**：面向“瞎扯”、问答合集和多个回答连续编排的内容。
2. **文章式「墨迹岛」**：面向“标题 + 作者 + 连续正文”的编辑文章。

两套模板均采用 **原生导航栏 + 单一可滚动 WKWebView**。不再使用外层 SwiftUI ScrollView 包裹禁止滚动的 WebView，也不在原生层重复渲染正文题图、标题或作者。

---

# 二、模板识别

## 1. 优先使用显式模板字段

如果 API 或本地 fixture 能增加模板类型，优先使用：

```swift
enum ArticlePresentationStyle: String, Codable {
    case qa
    case article
    case fallback
}
```

显式字段是最稳定的方案，避免根据文案猜测。

## 2. 无显式字段时的 DOM 识别

页面加载后使用 JavaScript 统计结构：

- 存在两个及以上问题节点（`Q:`、问题标题、question class）。
- 存在多个 answer / author 组合。
- 正文呈现重复的“问题 → 回答”序列。

满足以上结构时判为 `.qa`；否则有标题和连续段落时判为 `.article`；无法可靠识别时使用 `.fallback`，采用普通连续正文与普通导航标题。

**禁止只根据文章标题包含“瞎扯”判断。** 标题可作为弱信号，不能作为唯一依据。

---

# 三、共享原生层

## 1. 导航布局

```text
| 50pt 返回槽 | minmax(0, 1fr) 中央槽 | 50pt 操作槽 |
```

- 点击热区不小于 44×44pt。
- 左右槽固定等宽，中央内容相对屏幕居中。
- 问答式中央显示普通导航标题。
- 文章式中央显示墨迹岛胶囊。

## 2. “纸面压印”按钮语言

### 默认

- 纸色或透明背景。
- 靛蓝交互色。
- 9–11pt 圆角；导航返回按钮可保持圆形，但按压逻辑一致。
- 不使用通用投影。

### 按下

- 导航按钮 scale 0.92。
- 普通按钮 scale 0.96。
- 80–100ms 内出现靛蓝 10–17% 纸面底色。
- 释放后 140–210ms 回到稳定状态。

### 类型

- 导航图标按钮。
- 主按钮：每个上下文最多一个，靛蓝实底。
- 次级按钮：靛蓝描边，用于关注、重试和讨论入口。
- 文字按钮：取消、关闭等低优先动作。
- 菜单项：46pt 高，左图标、中标签、右状态。

### 状态

Default、Pointer、Focus、Pressed、Disabled、Loading、Success 均需实现；Reduce Motion 下取消缩放位移，保留颜色和语义变化。

## 3. 操作菜单

两类页面完全一致：

1. 分享文章。
2. 收藏 / 取消收藏。
3. 设为已读 / 未读。
4. 分隔线。
5. 不感兴趣 / 恢复到日报。

收藏采用乐观更新；不感兴趣执行后给撤销反馈，不弹低价值确认框。

## 4. 图片浏览器

- 点击正文图片进入全屏查看。
- 双击缩放、拖拽、单击关闭。
- 长按提供保存、复制、分享。
- VoiceOver 读取 alt 或“正文图片，第 N 张”。

## 5. 链接路由

- 站内链接：NavigationStack。
- 外部 http(s)：安全浏览器。
- 未知 scheme：拒绝，并给出可理解反馈。
- DOM 按下先显示 100ms 纸面压印底色。

## 6. 阅读能力

直接监听 `WKWebView.scrollView`：

- 阅读进度。
- 位置恢复。
- 返回顶部。
- 标题是否离开视口。
- 快速滚动状态。

移除 `htmlContentHeight`、WebView 高度回写和 `max(measuredHeight, 520)`。

---

# 四、问答式「问答长卷」

## 1. 页面结构

```text
Web 标题
作者 / 来源（条件渲染）
文武线
问题 1
回答作者 + 回答正文
问题 2
回答作者 + 回答正文
连续图片 / 图注
后续问答
讨论入口
```

## 2. 导航

- 标题仍在 Web DOM 中自然滚走。
- 标题底边离开导航栏后，中央显示 16pt 宋体标题副本。
- 不使用墨迹岛和常驻阅读进度，避免信息密度过高。
- 返回顶部按钮可以显示进度百分比。

## 3. 正文规格

| 元素 | 规格 |
|---|---|
| 页面水平边距 | 20pt；320pt 屏幕为 16pt |
| Web 标题 | 27pt 宋体特粗，行高 1.34 |
| 问题标题 | 20pt 宋体加粗，行高 1.55 |
| 问题段前 / 段后 | 30pt / 13pt |
| 回答竖线 | 2pt 淡墨 |
| 回答左缩进 | 15pt |
| 回答作者头像 | 有效时 26pt |
| 正文 | 16–17pt，行高 1.82 |
| 段落间距 | 18pt |
| 段落 → 图片 | 22pt |
| 连续图片 | 14pt |
| 图片 → 图注 | 8pt |

## 4. 头像

- 页面作者头像有效则保留 38pt。
- 每个回答作者头像有效则保留 26pt。
- 无头像时折叠槽位；失败但有作者名时使用首字。
- 不强制为所有回答生成占位头像。

## 5. 图片

- 严格遵循 HTML 出现顺序。
- 不在原生层提前插入 `detailImageURL`。
- 保留原始宽高比，最大宽度为正文宽度。
- 7pt 圆角或来源要求的直角，不统一做卡片。

---

# 五、文章式「墨迹岛」

## 1. 页面结构

```text
Web 完整标题
作者头像 + 作者名 + 身份 / 阅读时长 + 关注
可选题图 + 图注
文武线
导语 / 正文
分节标题
引用 / 列表 / 图片 / 链接
相关文章 / 讨论入口
```

题图可选。无题图时文武线直接连接正文，不保留媒体容器高度。

## 2. 开篇节奏

| 关系 | 间距 |
|---|---:|
| 标题 → 作者 | 18pt |
| 作者 → 题图 | 22pt |
| 题图 → 图注 | 8pt |
| 图注 → 文武线 | 20pt |
| 无题图：作者 → 文武线 | 19pt |
| 文武线 → 正文 | 22pt |

- 完整标题 27pt 宋体特粗。
- 可使用首字下沉，但仅用于文章首段，问答式禁用。
- 分节标题 21pt 宋体加粗，段前 30pt。
- 引用使用 3pt 靛蓝竖线和 18pt 宋体。

## 3. 墨迹岛导航

### 默认

- 高度 36pt。
- 最大宽度：320pt 屏 168pt；390pt 屏 220pt；430pt 屏 238pt；iPad 320pt。
- 背景 `DS.paperElevated`，0.7pt 髮丝线，18pt 圆角。
- 左侧 4pt 朱砂纵向进度刻度。
- 中央 14pt 宋体标题，单行尾部省略。

### 出现条件

- 当 Web 标题底边离开导航栏下沿后出现。
- 建议使用标题 DOM 哨兵消息，而不是固定 64pt 假设，以兼容不同标题行数和动态字号。
- 反向滚动时标题重新进入视口，墨迹岛退出。

### 动效

- 进入：220ms expo-out；opacity 0→1、Y 6→0、scale .98→1。
- 退出：165ms ease-in。
- 进度刻度跟随阅读进度更新，100ms 线性收敛。
- 不自动跑马灯，不持续闪动。
- Reduce Motion：取消 Y 与 scale，仅显隐；进度值仍实时更新。

### 点击展开

点击墨迹岛，在导航栏下展示：

- 完整标题。
- 24pt 作者头像（有头像才显示）。
- 作者名 / 来源。
- 已阅读百分比。

点击空白、再次点击或继续滚动后收起。

### 大字号

AX3 以上：胶囊显示“文章标题”，点击后查看全文。VoiceOver 标签始终是完整标题，值为“已阅读 N%”。

---

# 六、WebView DOM 与消息桥

## 1. 统一 DOM 标记

```html
<article data-template="qa|article|fallback">
  <h1 data-article-title>...</h1>
  <header data-byline>...</header>
  <figure data-hero>...</figure>
  <main data-content>...</main>
</article>
```

## 2. 消息通道

- `titleVisibility`：标题是否在视口。
- `documentMetadata`：模板、作者、头像、来源、题图信息。
- `imageClicked`：图片 URL、alt、图注、尺寸。
- `linkClicked`：URL、文字、是否站内。
- `readingMetrics`：offset、maximumOffset、percentage。
- `contentError`：图片或正文子资源失败。

## 3. 样式分层

- `base.css`：色彩、字号、段落、链接、图片、按钮。
- `qa.css`：问题、回答、回答作者和连续图片节奏。
- `article.css`：导语、首字下沉、分节标题、题图和引用。
- 深浅色和字号由 CSS variables 注入，不重新拼接大量样式字符串。

---

# 七、SwiftUI 组件计划

```text
ArticleDetailContainer
├── ArticleNavigationBar
│   ├── PaperPressIconButton
│   ├── PlainArticleNavTitle       // qa / fallback
│   ├── InkIslandTitle             // article
│   └── ArticleActionMenu
├── ArticleWebView
├── ArticleTitlePanel
├── FullScreenImageViewer
├── SafeLinkPresenter
└── ReadingProgressButton
```

建议状态模型：

```swift
struct ArticleDocumentState: Equatable {
    var style: ArticlePresentationStyle
    var title: String
    var author: ArticleAuthorMetadata?
    var isTitleVisible: Bool
    var readingProgress: Double
    var canShare: Bool
}
```

---

# 八、实施阶段

## Phase 1：滚动架构

- WebView 改为唯一滚动容器。
- 迁移阅读进度、位置恢复和返回顶部。
- 删除 `contentHeight` 与外层详情 ScrollView。

**验收：** 长文、短文、图片延迟加载均无额外空白或跳动。

## Phase 2：模板识别

- 增加 `ArticlePresentationStyle`。
- 优先读取显式字段；建立 DOM fallback。
- 准备 qa、article、fallback fixtures。

**验收：** 样本集识别稳定，无法判断时安全回落 fallback。

## Phase 3：共享 Web 样式

- 实现 base.css、按钮、头像、图片、链接、引用和错误状态。
- 接入图片与链接消息桥。

**验收：** 两模板共享视觉令牌，按钮状态一致。

## Phase 4：问答式模板

- 问题、回答、作者和多图节奏。
- 普通导航标题副本。

**验收：** 用户截图类型无重复题图、无断裂空白。

## Phase 5：文章式墨迹岛

- 题图条件渲染。
- 标题哨兵与墨迹岛。
- 完整标题面板和阅读进度。

**验收：** 1–4 行标题、无题图、无作者、200% 字号均稳定。

## Phase 6：测试与迁移

- 单元测试模板识别与 URL 路由。
- 快照测试浅色/深色、320/390/430pt、iPad 分栏。
- UI 测试标题交接、菜单、图片、链接、进度与位置恢复。
- 抽样真实文章对比旧版与新版，灰度替换。

---

# 九、测试矩阵

| 维度 | 覆盖值 |
|---|---|
| 模板 | qa / article / fallback |
| 标题 | 1 / 2 / 4 行；中文 / 英文 / 混排 |
| 作者 | 有头像 / 无头像 / 加载失败 / 无作者 |
| 媒体 | 无图 / 题图 / 单图 / 连续多图 / 加载失败 |
| 字号 | 100% / 150% / 200% |
| 屏幕 | 320 / 375 / 390 / 430pt / iPad 分栏 |
| 外观 | 浅色 / 深色 / 高对比度 |
| 动效 | 标准 / Reduce Motion |
| 网络 | 正常 / 缓慢 / 离线缓存 / 子资源失败 |
| 链接 | 站内 / 外链 / 未知 scheme |

---

# 十、最终验收标准

1. 两种正文风格能稳定区分并正确回落。
2. 问答式保持连续信息流，不显示墨迹岛。
3. 文章式标题离开视口后出现墨迹岛，点击可读取完整标题。
4. 所有正文内容位于一个滚动 WebView，无 520pt 假空白。
5. 原生层不重复插入题图、标题和作者。
6. 有头像保留，无头像折叠，失败状态不破坏布局。
7. 图片、链接、菜单和关注等按钮遵循同一“纸面压印”语言。
8. 200% 字号、深色模式和 Reduce Motion 可用。
9. VoiceOver 可读取完整标题、作者、图片 alt、链接和进度。
10. 阅读位置恢复、返回顶部和收藏分享功能不回归。
