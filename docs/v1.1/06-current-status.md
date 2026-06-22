# v1.1 当前状态与恢复入口

## 当前分支与提交

- 分支：`antigravity/daily-news-dev`
- 最近提交：
  - `fc626ae Add branded launch screen`
  - `d96e27a Reduce first article load stutter`

## 已完成能力

- 4 Tab 主导航：日报 / 收藏 / 已读 / 设置。
- 冷宫入口移入设置页。
- 本地冷宫、收藏、已读持久化。
- 已读记录按最近阅读时间排序，并支持搜索。
- 文章详情菜单按来源差异化展示。
- 详情页隐藏 TabBar。
- 正文图片全屏预览与缩放。
- 文章正文字体、列表字体可调。
- 首页完整 Feed 缓存优先展示。
- 历史日报缓存 fallback。
- 详情 cache-first 加载。
- `UILaunchScreen` 品牌启动页。
- `WKWebView` 首次加载预热，降低第一次打开文章顿卡。

## 最近验证

已执行：

```bash
xcodebuild -project 知乎日报-SwiftUI.xcodeproj -scheme DailyReader -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

结果：`BUILD SUCCEEDED`

非阻塞 warning：

- `All interface orientations must be supported unless the app requires full screen.`

## 当前工作区注意事项

截至本文档整理时，工作区中存在一个与文档/卡顿修复无关的已 staged 改动：

- `DailyReader/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`

内容是补充 iPad app icon slot。该改动没有被纳入 `d96e27a` 卡顿修复提交，后续可单独决定是否提交。

## 如果需要继续恢复工作

建议从这里开始：

1. 先运行 `git status --short --branch` 看是否仍有 AppIcon 或文档改动待处理。
2. 如需提交文档，检查：
   - `docs/README.md`
   - `docs/v1.1/01-product-requirements.md`
   - `docs/v1.1/02-implementation-plan-A.md`
   - `docs/v1.1/05-walkthrough.md`
   - `docs/v1.1/06-current-status.md`
3. 如需做下一轮体验优化，优先考虑：
   - orientation warning 是否需要收敛；
   - 详情页真实设备冷启动帧率验证；
   - 启动屏视觉是否需要和 AppIcon 进一步统一。
