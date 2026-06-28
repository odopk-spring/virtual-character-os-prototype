# 15 — 开源参考方向

## 15.1 可以直接用的

| 方向 | 推荐 | 用途 | 注意 |
|------|------|------|------|
| SwiftUI Chat UI | [ExyteChat](https://github.com/exyte/Chat) | 消息列表基础组件 | 需自定义气泡样式和状态栏 |
| SQLite | [GRDB](https://github.com/groue/GRDB.swift) | 本地数据库 | 强烈推荐，比 SwiftData 适合复杂查询 |
| Keychain | Apple Security Framework | API Key 存储 | 原生即可，无需第三方 |
| Markdown | [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | 消息中的富文本 | 轻量渲染 |
| 网络 | URLSession (原生) | API 调用 | async/await + bytes.lines 做流式 |
| 加密 | CryptoKit (原生) | E2E 加密 | Cloud Life Mode 需要 |

## 15.2 概念借鉴

| 方向 | 借鉴来源 | 借鉴什么 | 不可照搬的原因 |
|------|---------|---------|--------------|
| 世界书/设定集 | [SillyTavern Lorebook](https://github.com/SillyTavern/SillyTavern) | 关键词触发、优先级、冷却、层级世界书 | 耦合前端 Web 架构，需自研 iOS 原生版本 |
| 角色卡 | SillyTavern Character Card | 角色定义格式（JSON 结构） | PNG 嵌入元数据不适合移动端，可借鉴 JSON schema |
| 记忆系统概念 | [MemGPT](https://github.com/cpacker/MemGPT) | 分层记忆、记忆管理 prompt | 架构完全不同的产品场景；MemGPT 面向 agent 任务，我们面向人格模拟 |
| 记忆系统概念 | [Generative Agents 论文](https://arxiv.org/abs/2304.03442) | Memory Stream、Reflection、Planning | 学术架构需工程化适配 iOS；反思权重和遗忘曲线需自研 |
| RAG 架构 | [LlamaIndex](https://github.com/run-llama/llama_index) | 检索-排序-组装管道 | Python 生态，不适合 iOS；借鉴 Node 解析逻辑 |
| RAG 架构 | [LangChain Memory](https://github.com/langchain-ai/langchain) | Memory 类型分类思路 | 过度抽象，不适合移动端 |
| 角色扮演 | [Character.AI](https://character.ai) | Persona 设计、角色市场概念 | 闭源；人格定义太简单，无时间流 |
| 本地 AI | [Llama.cpp](https://github.com/ggerganov/llama.cpp) | 本地模型推理 | MVP 暂不需，后期可探索本地 embedding |
| 嵌入 | [sentence-transformers](https://www.sbert.net/) | embedding 模型 | 初期用 API，后期可本地运行 |
| 聊天 UI 设计 | iMessage, 微信, Telegram | 消息气泡、送达状态、输入指示器 | 不要照搬"即时通讯"的全部隐喻——角色不是真人，不应制造"秒回"预期 |

## 15.3 必须自研的

| 模块 | 原因 |
|------|------|
| Context Builder | 核心编排逻辑，行业无现成方案 |
| Life Scheduler | iOS 限制下的独特时间流实现，无开源参考 |
| Proactive Messaging Engine | 行业空白——没有产品认真做过"虚拟人物的主动消息" |
| Realism Engine | 行业空白——真实感从未被工程化 |
| Relationship Evolution | 现有的"好感度系统"都是恋爱导向，需全新设计 |
| World Book Trigger Engine | SillyTavern 的概念好但实现不够精细，需重构 |
| Memory Decay Model | MemGPT 等有基础概念但无衰减机制，需自研 |
| BYOK Provider Adapter | 需要统一的 Swift 原生适配，现有方案多是 Python |

## 15.4 论文参考

| 论文 | 关键概念 | 应用 |
|------|---------|------|
| [Generative Agents (Park et al., 2023)](https://arxiv.org/abs/2304.03442) | Memory Stream, Reflection, Planning | 记忆系统架构的学术基础 |
| [MemGPT (Packer et al., 2023)](https://arxiv.org/abs/2310.08560) | Virtual Context Management | 分层记忆和上下文管理 |
| [AI Companions Reconsidered](https://arxiv.org/abs/2401.01575) | AI 陪伴的社会影响分析 | 安全边界和依赖检测的设计参考 |
| [The ELIZA Effect](https://en.wikipedia.org/wiki/ELIZA_effect) | 用户如何拟人化 AI | 产品叙事中需要在真实感和诚实之间平衡 |

## 15.5 搜索关键词建议

当开始实际开发时，可以搜索以下关键词寻找最新资源：

```
- "swiftui chat interface github"
- "ios local vector database"
- "swift keychain wrapper"
- "openai streaming swift"
- "anthropic api swift"
- "grdb swiftui tutorial"
- "ios local notification rich content"
- "swiftui message bubble"
- "core data vs grdb swift 2024"
- "ios background task scheduler reliability"
```
