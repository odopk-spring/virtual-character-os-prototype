# MVP_SCOPE

> 防止开发范围膨胀。任何任务如果不在当前 MVP 范围内，不能实现。

## Purpose

这个文件定义 MVP 0 / MVP 1 / MVP 2+ 的精确边界。每个阶段明确列出**必须做**和**明确不做**的事项。

**执行规则**：如果某功能在当前 MVP 范围的"不做"列表中，或不在"必须做"列表中 → 不能实现。只能写 `// TODO: MVP X` 或接口占位。

## MVP 0: Technical Chat Loop

**目标**：验证最小 BYOK 聊天闭环。不追求完整人格系统。只有一个问题要回答——"用户能不能用自己的 API Key 和一个有基本人格的角色聊天？"

### MVP 0 必须做

1. SwiftUI App 可以启动，有空白页面。
2. 单角色固定角色档案（硬编码或 JSON 文件，不由用户编辑）。
3. Provider Settings 页面。
4. 用户可以填写 Base URL。
5. 用户可以填写 Model Name。
6. 用户可以填写 API Key。
7. API Key 使用 Keychain 保存。
8. OpenAI-compatible 请求（先非流式；流式可选实现，不阻塞 MVP 0）。
9. 基础 Chat View。
10. 用户可以发送消息。
11. App 可以调用模型并显示回复。
12. 消息本地保存（简单方案即可：文件/GRDB/SwiftData 三选一，说明理由）。
13. 重启后消息仍在。
14. 基础错误处理：网络错误、Key 错误、模型错误、限速/余额错误。
15. Character Profile v0（固定角色名 + 人格描述 + 默认关系）。
16. Context Builder v0：角色设定 + USER_PERSONA_V0 摘要 + REALISM_V0 规则摘要 + 最近消息。
17. Review Gate 每轮报告（按 REVIEW_GATE.md 格式）。

### MVP 0 明确不做

1. 不做复杂长期记忆系统。
2. 不做 MemoryItem 自动抽取。
3. 不做世界书 RAG。
4. 不做主动消息。
5. 不做 APNs 推送。
6. 不做后端。
7. 不做云同步。
8. 不做多角色。
9. 不做角色市场。
10. 不做复杂 Life Scheduler。
11. 不做关系状态机。
12. 不做完整情绪模型。
13. 不做多模型高级路由（Provider 协议可以写，但只实现 OpenAI-compatible）。
14. 不做图片、语音、工具调用。
15. 不做 App Store 商业功能（内购、订阅、付费墙）。
16. 不做流式输出（除非实现成本极低且不阻塞其他任务）。

## MVP 1: Real Character Foundation

**目标**：在 MVP 0 可用聊天闭环上，加入基础真实感能力。问题——"角色能不能不像客服？能不能有点记忆？"

### MVP 1 允许做

1. Character Editor 基础版（表单式，编辑角色名、人格描述、默认关系）。
2. MemoryItem 基础模型（仅 SQLite 表 + Swift struct，不做自动抽取）。
3. 手动记忆查看（记忆列表页面）。
4. 手动记忆添加（用户在记忆页手动创建记忆）。
5. 手动记忆编辑（用户修改已有记忆）。
6. 手动记忆删除（用户删除记忆）。
7. 基础 WorldBookEntry（仅数据模型 + 手动 CRUD）。
8. 世界书手动添加 / 编辑 / 删除。
9. Context Builder v1：最近消息 + 用户画像 + 角色人格 + 少量手动记忆 + 少量世界书（如有触发）。
10. 简单角色状态：online / busy / resting / sleeping（基于当前时间查固定模板）。
11. 简单回复延迟模拟（可配置开关，默认开）。
12. 基础真实感测试样例（手动验证角色回复是否像网友）。

### MVP 1 明确不做

1. 不做全自动复杂记忆合并。
2. 不做复杂矛盾检测（可做简单关键词相似提醒，但不做向量去重）。
3. 不做向量数据库（不做 embedding 检索）。
4. 不做云端主动消息。
5. 不做复杂日程生成器（不用 LLM 生成每日计划）。
6. 不做多角色生态。
7. 不做角色市场。
8. 不做关系自动演化（关系状态手动设置或固定）。

## MVP 2+: Deferred

以下全部推迟到 MVP 2 及以后。MVP 0/1 阶段绝对禁止实现：

1. 完整 Life Scheduler（动态日程生成、离线时间补算）。
2. Proactive Messaging Engine。
3. APNs 主动推送。
4. 云端 Life Mode（后端、账号、加密同步）。
5. 多设备同步。
6. 多角色关系图（角色间互动）。
7. 世界线演化。
8. 复杂关系状态机（自动演化）。
9. 创作者模板市场。
10. 高级 RAG / embedding / vector search。
11. 复杂记忆反思与合并。
12. 商业订阅系统（内购、订阅、付费墙）。
13. 本地模型推理。
14. iPad / Apple Watch 适配。
15. Widget。

## Scope Rule

如果某功能看起来有用，但不在当前 MVP 范围内，**只允许**：

* 写 `// TODO: MVP X — [功能说明]`。
* 写 Protocol 接口定义（不做实现）。
* 在 TASKS.md 的未来任务列表中记录。

**不允许提前实现任何逻辑。不允许"顺手做"。不允许"反正很简单就一起做了"。**

## Non-functional Requirements (All MVPs)

以下要求在所有 MVP 阶段生效：

* API Key 必须存 Keychain，禁止存 UserDefaults。
* API Key 禁止打印到日志。
* 所有网络调用必须是 HTTPS。
* 用户数据（消息、角色配置、记忆）默认本地存储。
* 不对用户隐藏"这是虚拟人物"的事实。
* 不默认恋爱关系。
* 不假装真人。
