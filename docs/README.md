# 《日报阅读器》文档中心

当前发布版本为 **2.0**。文档按“版本、功能、设计、测试、归档”分类，避免需求、设计稿和过程记录散落在仓库根目录。

## 快速入口

- [2.0 发布说明](releases/v2.0/README.md)
- [项目设计系统](design/design-system.md)
- [自动化测试基础设施](testing/automation-infrastructure-v1.2.md)

## 目录结构

### `releases/` — 版本资料

- [`v2.0/`](releases/v2.0/)：当前版本发布说明、核心能力和验证结论。
- [`v1.2/`](releases/v1.2/)：网络层、热榜、个人阅读管理等 1.2 需求与实施资料。
- [`v1.1/`](releases/v1.1/)：阅读管理、设置、性能与体验优化资料。
- [`v1.0/`](releases/v1.0/)：日报阅读基础闭环、测试与验收归档。

### `features/` — 功能需求与架构

- [`article-detail/`](features/article-detail/)：双正文模式需求和技术架构。
- [`home-density/`](features/home-density/)：首页高／中／低三档信息密度切换需求。
- [`zhihu-login/`](features/zhihu-login/)：已隐藏的知乎登录实验需求和架构。

### `design/` — 设计规范与可视化产物

- [`design-system.md`](design/design-system.md)：全局“今日刊”视觉系统。
- [`article-navigation/`](design/article-navigation/)：正文导航、双正文和 WebView 设计。
- [`article-metrics/`](design/article-metrics/)：文章互动数据设计、实现记录与运行截图。
- [`ai-reading-assistant/`](design/ai-reading-assistant/)：AI 阅读助手 UI 规格和可视化设计稿。

### `testing/` — 测试规范

- [`automation-infrastructure-v1.2.md`](testing/automation-infrastructure-v1.2.md)：UI 自动化基础设施、Mock 场景和分层测试矩阵。

### `archive/` — 历史过程资料

- [`v1.2-development/`](archive/v1.2-development/)：1.2 开发期的原始请求、项目计划和进度记录，仅作追溯。

## 维护规则

1. 新版本资料放入 `docs/releases/vX.Y/`。
2. 跨版本长期有效的功能文档放入 `docs/features/`。
3. 设计系统、设计规范、HTML 原型和设计截图放入 `docs/design/`。
4. 测试策略与基础设施放入 `docs/testing/`。
5. 已过时但仍需追溯的过程资料移入 `docs/archive/`，不在根目录继续堆放。
6. 仓库根目录仅保留工程、配置和源码入口，不新增临时交付文档。
