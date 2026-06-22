# 项目计划：知乎日报-SwiftUI v1.2 开发

## 目标
开发日报阅读器 App v1.2 版本，主要功能如下：
1. 将网络底层替换为 Alamofire，移除非公开接口反爬拦截。
2. 引入知乎热榜 API（前 50 条），支持点击进入回答列表（前 20 条回答的作者、头像、赞同数和摘要），并支持通过 HTMLWebView 查看回答正文。
3. 重构 TabBar 为 4 个主 Tab，将“已读”和“收藏”合并为“我的”页面。顶部采用药丸胶囊背景滑动切换栏，下方提供统一搜索框。
4. 基于 iOS 原生 Keychain 钥匙串实现本地数据的防卸载丢失与静默恢复。
5. 将单元测试迁移至最新的 Swift Testing 框架，UI 测试保持使用 XCTest。

## 复杂度评估
- **范围**: 涉及多个模块的代码修改，包含网络层、存储层和 UI 交互层（中等偏高）。
- **知识**: 需要熟悉 Swift, SwiftUI, Alamofire 库, iOS Keychain 原生 API，以及最新的 Swift Testing 框架（中等）。
- **风险**: 网络与本地存储的修改是应用的核心，若有遗漏容易引发崩溃或数据丢失（中等偏高）。
- **模糊性**: 药丸胶囊滑块过渡动画及网页渲染需要严密的前端样式匹配（中等）。

**策略**: 采用 **Project Pattern**（项目模式）双轨并行：E2E 测试轨与业务开发轨。通过分发子任务给子编排器（sub-orchestrator）按顺序执行里程碑。

---

## 架构与里程碑分解
项目被划分为 **6 个里程碑**：

| 里程碑 | 名称 | 目标描述 | 依赖项 | 工作目录 |
|---|---|---|---|---|
| **M1** | Alamofire 迁移 | 更新 `project.yml` 引入依赖，改写 `HTTPClient.swift` 支持 Alamofire 及合理的 `User-Agent` 头部。 | 无 | `.agents/sub_orch_m1` |
| **M2** | 热榜与回答列表 | 实现热榜模型、扩展 `DailyAPIClient`、新建热榜列表页、回答列表页及 HTMLWebView 详情页。 | M1 | `.agents/sub_orch_m2` |
| **M3** | “我的”页面合并 | 调整 Tab 导航，实现药丸胶囊滑块平滑切换收藏与已读，提供统一搜索过滤功能。 | M2 | `.agents/sub_orch_m3` |
| **M4** | Keychain 数据备份 | 编写 `KeychainHelper`。在 ViewModel 写入 UserDefaults 时双写 Keychain，并在重装检测到为空时自动静默恢复。 | 无 | `.agents/sub_orch_m4` |
| **M5** | 单元测试迁移 | 将 `DailyReaderTests` 目录下的所有 XCTest 单元测试重构为 Swift Testing 语法。 | 无 | `.agents/sub_orch_m5` |
| **M6** | E2E 与对抗测试 | 接入 E2E 测试套件验证全部通过，并执行第 5 阶段对抗性覆盖率测试与 Bug 修复。 | M1-M5, E2E轨 | `.agents/sub_orch_m6` |

同时并行推进：
- **E2E 测试轨 (E2E Testing Track)**：开发黑盒测试套件（Tiers 1-4），并在完成后生成 `TEST_READY.md`。工作目录：`.agents/e2e_orch`

---

## 角色分配与任务委派计划
1. **E2E 测试编排器**
   - 任务：编写基于 XCTest 的全面 UI 自动化测试用例，覆盖功能覆盖率、边界与角部用例、跨功能组合及真实使用场景。
   - 产物：`TEST_INFRA.md` 与 `TEST_READY.md`。
2. **各个里程碑子编排器 (M1 - M5)**
   - 任务：接收里程碑范围，使用 Explorer -> Worker -> Reviewer 循环完成特定编码任务。
   - 产物：完成对应模块的重构与功能，并通过单元测试验证。
3. **M6 集成与对抗编排器**
   - 任务：协调 E2E 验证（Phase 1）与 Challenger 对抗性安全强化测试（Phase 2）。

---

## 验证与诚信保障
- **Forensic Auditor (法证审计)**：各子编排器在每次执行 Worker 修改后必须通过法证审计员的独立合规审计。严禁伪造测试、硬编码或空壳实现。
- **Git Commit 规则**：每次完成修复并验证通过后自动提交，提交分支必须保持 `antigravity/` 前缀。
