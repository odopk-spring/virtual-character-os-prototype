# 04 — 模块详解

每个模块说明：解决的问题、输入、输出、依赖、MVP 简化、高级扩展、自研 vs 借鉴。

---

## 4.1 Character Profile / 角色人格层

### 解决的问题
定义"这个角色是谁"——核心人格、背景、说话方式、价值观。确保角色在所有对话中保持一致的人格基础。

### 数据结构

```swift
struct CharacterProfile: Codable {
    var id: String
    var name: String
    var nickname: String?           // 用户对TA的称呼
    var archetype: CharacterArchetype
    var coreTraits: [PersonalityTrait]  // 核心人格维度
    var speakingStyle: SpeakingStyle
    var background: String          // 背景故事（自由文本）
    var worldview: String           // 世界观/价值观简述
    var interests: [String]         // 兴趣
    var dislikes: [String]          // 不喜欢的事物
    var quirks: [String]            // 小习惯、口头禅
    var boundaries: [String]        // 明确的边界
    var emotionalRange: EmotionalRange
    var avatar: Data?               // 头像（可选）
    var createdAt: Date
    var updatedAt: Date
}

struct PersonalityTrait: Codable {
    var dimension: TraitDimension   // 如 openness, warmth, assertiveness
    var value: Double               // 0.0 - 1.0
    var expression: String          // 自然语言描述该维度表现
}

enum TraitDimension: String, Codable {
    case warmth          // 温暖度
    case assertiveness   // 主见性
    case openness        // 开放度
    case energy          // 能量水平
    case patience        // 耐心程度
    case humor           // 幽默感
    case seriousness     // 严肃度
    case independence    // 独立性
    case curiosity       // 好奇心
    case formality       // 正式程度
}
```

### 输入
- 用户通过角色编辑器手动填写
- 从角色模板/角色包导入
- 从其他平台的角色卡导入（如 Character.AI、SillyTavern 导出）

### 输出
- 序列化为 system prompt 的 Character Core 段落
- 被 Life Scheduler 读取以决定日常行为
- 被 Realism Engine 读取以决定回复风格
- 被 Relationship Dynamics 读取以决定关系基线

### 依赖
- 无（基础模块，被几乎所有其他模块依赖）

### MVP 简化
- 只支持 5 个核心维度（warmth, energy, formality, humor, assertiveness）
- 角色编辑用文本字段，不用复杂滑块
- 提供 3-5 个预设模板，快速开始

### 高级扩展
- 角色性格随时间缓慢演化（personality drift）
- 角色有"成长弧"（character arc）
- 角色之间有关系定义（用于多角色群组）
- 角色状态影响性格表达（如疲惫时更内向）

### 自研 vs 借鉴
- **借鉴**：SillyTavern 的 character card 格式、Character.AI 的 persona 设计思路
- **自研**：人格维度模型、性格与时间流/关系的联动机制

---

## 4.2 Memory System / 长期记忆系统

### 解决的问题
让角色记住该记住的事，忘记该忘记的事。不是简单的聊天记录搜索，而是结构化、多层次、有遗忘机制的记忆系统。

> 详见 [05-memory-system.md](05-memory-system.md)，此处仅概要。

### 概要结构

| 记忆层 | 存储内容 | 容量 | 衰减速度 |
|--------|---------|------|---------|
| Raw Messages | 完整对话记录 | 全部 | 不衰减 |
| Short-term | 最近 N 轮对话 | 小 | 快速过期 |
| Episodic | "发生了什么" | 中 | 中等 |
| Semantic | "知道了什么" | 中 | 慢 |
| Emotional | "感受如何" | 中 | 中等 |
| Relationship | "关系如何变化" | 小 | 很慢 |
| Reflection | 周期性总结 | 小 | 不衰减 |
| Topic Documents | 按主题整理 | 小 | 不衰减 |
| World-linked | 与世界书关联 | 视世界书大小 | 跟随世界书 |
| Correction | 用户纠正记录 | 小 | 不衰减 |

### MVP 简化
- Short-term + Semantic + 简单 Episodic
- 无自动抽取，用户手动添加记忆
- 简单关键词检索 + 最近时间排序

### 高级扩展
- 自动记忆抽取（LLM 驱动的 reflection）
- 向量检索
- 记忆合并/去重
- 遗忘曲线
- 跨会话记忆整理
- 主题聚类

---

## 4.3 World Book / 世界书与设定集 RAG

### 解决的问题
让角色理解自己所在的世界——世界观设定、人物关系、地点、时间线、规则。世界书是"世界本来的样子"，不是"角色经历了什么"。

> 详见 [06-world-book.md](06-world-book.md)，此处仅概要。

### 与记忆的严格区分

| | 世界书 | 记忆系统 |
|---|--------|---------|
| 内容 | 世界本来是什么样的 | 角色经历过什么 |
| 来源 | 用户显式定义 | 对话自动/半自动抽取 |
| 修改 | 用户手动编辑 | 系统自动更新 + 用户纠正 |
| 触发 | 关键词/向量匹配 | 相关性 + 时间 + 重要性 |
| 遗忘 | 不遗忘（除非用户删除）| 有遗忘机制 |

### MVP 简化
- 每个角色一个全局世界书文件
- 仅关键词触发
- 上限 50 条条目

### 高级扩展
- 向量检索 + 关键词混合触发
- 分层世界书（全局/角色/会话）
- 设定矛盾检测
- Canon 层级管理
- 世界书模板市场

---

## 4.4 Context Builder / 上下文组装器

### 解决的问题
每次对话前，从各模块收集相关信息，组装成发送给模型的完整 prompt。管理 token 预算，做优先级排序。这是整个系统的"大脑"。

> 详见 [07-context-builder.md](07-context-builder.md)，此处仅概要。

### 核心职责
1. 收集：读取各模块的输出
2. 排序：按重要性排序检索结果
3. 预算：在 token 限制内装入最多有价值信息
4. 组装：按标准结构拼装最终 prompt
5. 发送：调用 BYOK Provider
6. 后处理：保存消息、触发记忆抽取、更新状态

### MVP 简化
- 固定 prompt 模板
- 简单优先级：最近消息 > 世界书 > 长期记忆
- Token 预算简单截断

### 高级扩展
- 动态 prompt 结构
- 智能 token 分配
- 多轮检索（先检索再细化）
- 意图感知的检索策略

---

## 4.5 Life Scheduler / 时间流与日程系统

### 解决的问题
虚拟人物不是永远在线等待用户。TA 有自己的日程——睡觉、工作、学习、休息、社交、娱乐。角色在不同时间有不同的状态，这直接影响回复延迟、回复风格和可用性。

> 详见 [08-life-scheduler.md](08-life-scheduler.md)，此处仅概要。

### 核心概念
- 角色有"离线生活"——即使用户不在，时间也在流逝
- 用户打开 App 时，系统补算时间流逝带来的状态变化
- 角色的日程是人格相关的——学生角色有课表，上班族有工作时间

### MVP 简化
- 固定每日模板（睡觉 0-7，工作 9-17，自由 18-23）
- 基于当前时间查表获取状态
- 无"离线生活"补算

### 高级扩展
- 动态日程生成（LLM 每日生成当日计划）
- 离线时间补算（心情变化、做了什么事）
- 角色间日程冲突处理（多角色）
- 用户事件同步（日历集成）

---

## 4.6 Proactive Messaging / 主动消息系统

### 解决的问题
真实的朋友不会只在被找时才说话。角色需要能主动联系用户——分享生活、关心近况、纪念重要事件。但主动消息不能像营销推送，必须自然、有个性、频率可控。

> 详见 [09-proactive-messaging.md](09-proactive-messaging.md)，此处仅概要。

### 触发类型
1. 时间触发（如每天早上问候、晚上道晚安）
2. 记忆触发（如用户明天有考试，前一晚主动加油）
3. 关系触发（如很久没联系，主动问候）
4. 生活触发（角色今天遇到了有趣的事）
5. 事件触发（用户的重要日期）
6. 世界书触发（世界书中的事件发生）

### MVP 简化
- 仅本地通知
- 低频（每天最多 1-2 条）
- 简单模板 + LLM 生成

### 高级扩展
- 云端 APNs 稳定推送
- 频率自动调节（根据用户回应率）
- 内容个性化（基于记忆和关系）
- 群组角色互相@

---

## 4.7 Relationship Dynamics / 关系状态演化

### 解决的问题
用户和虚拟人物之间的关系不是固定的。它随着互动变化——变近或变远。关系追踪系统确保角色的行为与当前关系状态一致。

> 详见 [10-relationship-dynamics.md](10-relationship-dynamics.md)，此处仅概要。

### 关系状态机

```
stranger → acquaintance → casual_friend → close_friend → companion
                 ↑              ↓              ↓
                 └──── distant ←────── conflict
                                      ↓
                                    repair
```

### MVP 简化
- 3 个状态：acquaintance / friend / close_friend
- 简单计数器：互动天数、消息数量
- 手动调节

### 高级扩展
- 多维关系向量
- 自动关系事件检测
- 关系预测和预警（疏远提醒）
- 多角色关系图

---

## 4.8 Realism Engine / 真实感控制器

### 解决的问题
将"真实感"工程化为可配置的规则和控制参数。确保角色的回复在长度、风格、延迟、情绪等方面符合真实人类的自然变化。

> 详见 [11-realism-engine.md](11-realism-engine.md)，此处仅概要。

### 控制维度
1. 回复长度变化（短/中/长）
2. 回复延迟
3. 情绪状态影响
4. 忙碌程度
5. 关系距离影响
6. 时间影响（早/中/晚/深夜）
7. 不确定性表达
8. 话题转移概率
9. 不完整句子频率
10. 主动分享概率

### MVP 简化
- 固定规则 + 随机变化
- 3 种回复模式（short/normal/long）
- 简单延迟（0-30 秒模拟）

### 高级扩展
- LLM 驱动的回复模式决策
- 角色人格相关的真实感参数
- A/B 测试不同真实感配置
- 用户偏好学习

---

## 4.9 BYOK Provider Layer / API 接入层

### 解决的问题
用户使用自己的 API Key，支持多种模型提供商。屏蔽不同 API 的差异，提供统一接口。

> 详见 [12-byok-api-layer.md](12-byok-api-layer.md)，此处仅概要。

### 支持的 Provider
1. OpenAI 兼容（含第三方代理）
2. Anthropic
3. DeepSeek
4. Gemini
5. OpenRouter / LiteLLM 兼容
6. 自定义 Base URL

### MVP 简化
- 仅 OpenAI 兼容接口
- 无流式
- 简单重试

### 高级扩展
- 全 Provider 支持
- 流式输出
- 智能路由（选择最便宜/最快的模型）
- 故障转移
- 本地模型支持

---

## 4.10 Local Storage / 本地数据层

### 解决的问题
所有本地数据的持久化、查询、迁移。确保数据安全、可导出、可删除。

### 技术选型：GRDB

```swift
// GRDB 提供 SQLite 的类型安全封装，适合复杂查询
// 比 SwiftData 更可控，比纯 SQLite 更安全
```

### 核心表
- characters
- messages
- memory_items
- world_book_entries
- relationship_states
- character_schedules
- user_settings
- api_configs（仅存 provider 类型，不存 key）

### MVP 简化
- 单数据库文件
- 简单 migration
- JSON 导出

### 高级扩展
- 加密数据库
- 增量同步
- 备份到 iCloud
- 数据库优化（索引、WAL 模式）

---

## 4.11 Optional Backend / 可选后端

### 解决的问题
- 稳定的主动消息推送（APNs）
- 跨设备加密同步
- 角色日程的持续运行（不依赖 iOS 后台）
- 云端记忆整理

### 设计原则
- **不做对话代理**：API 调用仍在本地（或用户授权后服务器使用加密 Key）
- **最小数据上传**：仅同步必要的状态数据
- **端到端加密**：同步数据在服务器端不可读
- **完全可选**：不连服务器也能正常使用核心功能

### MVP 简化
- 不做后端

### 高级扩展
- CloudKit 同步（苹果原生，零服务器成本）
- 独立后端（Vapor/Node.js）

---

## 4.12 Notification System / 通知系统

### 解决的问题
管理本地通知和远程推送。确保主动消息能被用户看到，但不骚扰。

### MVP 简化
- 仅本地通知
- 简单频率控制

### 高级扩展
- APNs + Notification Service Extension
- 通知分组
- 通知优先级
- 静默推送触发后台刷新

---

## 4.13 Safety & Boundary Layer / 安全与边界层

### 解决的问题
- 防止角色输出有害内容
- 防止角色鼓励用户过度依赖
- 防止角色被越狱
- 保护用户隐私
- 合规（App Store 审核）

### 实现
- System prompt 层面的安全指令
- 输入关键词过滤（轻量）
- 输出后检查（可选，消耗 token）
- 角色人格层面的边界定义
- 用户可配置的安全级别

### MVP 简化
- 仅 prompt 层面安全指令
- 无输出过滤

### 高级扩展
- 输出内容安全扫描
- 用户行为风险检测
- 过度依赖预警

---

## 4.14 UI Layer / iOS 界面层

### 解决的问题
提供直观、美观、有沉浸感的用户界面。界面应该让用户感觉在和虚拟人物相处，而不是在调试机器人。

> 详见 [14-ui-ux.md](14-ui-ux.md)，此处仅概要。

### 核心页面
1. Chat：对话页
2. Character Status：角色状态页
3. Memory：记忆管理页
4. World Book：世界书编辑页
5. Timeline：时间线页
6. Relationship：关系概览页
7. Character Editor：角色编辑器
8. API Settings：BYOK 配置页
9. Notification Settings：通知设置页
10. Privacy & Data：隐私与数据页

### MVP 简化
- Chat + 简单 Settings + 角色编辑
- 无记忆/世界书/关系可视化

### 高级扩展
- 完整页面
- 动画过渡
- iPad 适配
- Widget
- Apple Watch 伴侣

---

## 4.15 模块自研 vs 借鉴总结

| 模块 | 借鉴来源 | 自研原因 |
|------|---------|---------|
| Character Profile | Character.AI, SillyTavern 角色卡 | 需要与时间流/关系联动 |
| Memory System | MemGPT, LangChain Memory, Generative Agents | 架构完全不同（层级+遗忘+情绪） |
| World Book | SillyTavern Lorebook, NovelAI | 需要和记忆系统严格区分 |
| Context Builder | LangChain, LlamaIndex 概念 | 核心编排逻辑必须自研 |
| Life Scheduler | Generative Agents 论文 | iOS 限制下的独特实现 |
| Proactive Messaging | 无成熟借鉴 | 行业空白，必须自研 |
| Relationship Dynamics | Replika 好感度（反面参考） | 要避免恋爱诱导，架构不同 |
| Realism Engine | 无成熟借鉴 | 行业空白，必须自研 |
| BYOK Provider | OpenAI Swift, Anthropic Swift | 适配层可借鉴，多 Provider 切换自研 |
| Local Storage | GRDB 库 | 数据模型自研 |
| UI | SwiftUI 开源 Chat UI | 核心交互自研 |
