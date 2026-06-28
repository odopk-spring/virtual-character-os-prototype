# PROJECT_RULES

> 项目级不可越界规则。每轮开发必须遵守。优先级高于所有 PRD 文档。

## Product Identity

* 当前产品是 **iOS 虚拟人物生态 / Character OS / 虚拟网友系统**。
* **不是** AI 女友 App。
* **不是** ChatGPT 套壳。
* **不是** 单纯角色扮演聊天壳。
* 核心体验是：**真实感、长期记忆、角色边界、时间感、世界书、关系连续性**。
* MVP 0/1 阶段只验证最小真实聊天闭环，不实现完整生态。
* 产品定位详情见 `01-product-positioning.md`。

## Development Principles

* 每轮只做一个明确任务（从 TASKS.md 取）。
* 每轮必须先读 TASKS.md 当前任务。
* 每轮必须遵守 MVP_SCOPE.md 的范围约束。
* 每轮必须遵守 REVIEW_GATE.md 的检查门。
* 每轮必须按 LOOP.md 的执行流程。
* 每轮必须按 REVIEW_GATE.md 的报告格式输出结果。
* **不允许自动进入下一任务**——必须等待用户确认。
* **不允许擅自扩展需求**——用户没说的不做。
* **不允许为了"顺手"重构无关文件**——只改当前任务涉及的文件。

## Technical Rules

* SwiftUI first（UI 层）。
* OpenAI-compatible Provider first（API 层）。
* BYOK first（用户自带 Key，不替用户付模型费用）。
* API Key 必须存 Keychain。
* 禁止 API Key 存 UserDefaults。
* 禁止 API Key 打印到日志。
* MVP 0 不接后端。
* MVP 0 不做云同步。
* MVP 0 不做主动推送。
* MVP 0 不做复杂记忆系统。
* MVP 0 不做世界书 RAG。
* MVP 0 不做多角色。
* MVP 0 不引入大型第三方依赖（除非不可替代）。
* 所有 API 调用必须是 HTTPS。
* 所有文件路径必须使用 Apple 沙盒合规路径。

## Realism Rules

* 默认像虚拟网友 / 项目搭档，不像客服。
* 不默认恋爱关系。
* 不默认亲密称呼。
* 不假装真人。
* 不无条件讨好。
* 不每次长篇大论。
* 不每次列清单。
* 不没证据就说"我记得"。
* 真实感规则以 `REALISM_V0.md` 为准。
* 用户画像以 `USER_PERSONA_V0.md` 为准。

## Document Priority

后续每轮执行时的文档读取优先级（从高到低）：

1. **TASKS.md** — 当前任务定义
2. **MVP_SCOPE.md** — 范围边界
3. **PROJECT_RULES.md**（本文件）— 项目规则
4. **REVIEW_GATE.md** — 检查门
5. **REALISM_V0.md** — 真实感规则
6. **USER_PERSONA_V0.md** — 用户画像
7. 原始 22 个 PRD 文档（仅按需读取）

**冲突处理**：如果原始 PRD 与 MVP_SCOPE.md 冲突，**以 MVP_SCOPE.md 为准**。

## Git Rules

* 本目录需要在开始写代码之前初始化为 Git 仓库。
* 必须有 `.gitignore`，至少排除 `.DS_Store`、`xcuserdata`、`DerivedData`、`*.xcworkspace/xcuserdata`、`Pods/`。
* API Key 绝不能出现在 commit 中。
* Commit message 使用中文，简洁描述本轮做了什么。
* Push 之前必须 `git remote -v` 确认远程仓库地址。
