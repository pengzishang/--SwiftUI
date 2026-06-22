## 2026-06-22T14:41:56Z

你是一个只读分析代理（Explorer）。
工作目录：/Users/pengzishang/Current Project/知乎日报-SwiftUI/.agents/e2e_orch/explorer_infra_1

请执行以下任务：
1. 深入分析当前项目结构，特别是 `project.yml`、`DailyReaderUITests` 目录以及现有测试用例。
2. 根据 `PROJECT.md` 和 `ORIGINAL_REQUEST.md` 中的核心需求，详细规划并设计黑盒 UI 自动化测试用例，涵盖 4 个 Tier：
   - 功能覆盖测试 (Tier 1)：每个核心功能（1. 日报新闻阅读；2. 知乎热榜；3. "我的"胶囊切换与搜索；4. Keychain 备份与恢复）至少有 5 个测试用例。
   - 边界值与异常测试 (Tier 2)：每个核心功能至少有 5 个边界测试用例。
   - 跨功能组合测试 (Tier 3)：测试多功能交互和联动（Pairwise）。
   - 真实应用场景测试 (Tier 4)：模拟真实用户操作流，至少 5 个综合测试用例。
3. 遵循中文撰写约束，起草符合 `TEST_INFRA.md` 模板的内容。
4. 将起草的内容 and 你的分析报告以 `analysis.md` 写入你的工作目录，并写好 `handoff.md`。

注意：你只需要分析并起草内容，不需要直接在项目根目录下创建 TEST_INFRA.md，也不需要编写实际的 Swift 测试代码。
