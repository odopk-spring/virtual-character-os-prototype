# 21 — 第一阶段建议执行任务

## 总览

第一阶段目标：**3 个月内发布 MVP 2 级别的可用版本到 App Store。**

## 第 1-2 周：项目搭建 + MVP 0

### 任务清单

| # | 任务 | 优先级 | 预估 |
|---|------|--------|------|
| 1 | 创建 Xcode 项目，配置 SwiftUI + GRDB + SPM | P0 | 0.5天 |
| 2 | 设计并创建核心数据表（characters, messages） | P0 | 1天 |
| 3 | 实现 OpenAI-compatible Provider（流式） | P0 | 2天 |
| 4 | 实现 Keychain 存储 API Key | P0 | 0.5天 |
| 5 | 实现基础 Chat UI（消息列表 + 输入框 + 流式） | P0 | 2天 |
| 6 | 实现简单 system prompt + API 调用 | P0 | 1天 |
| 7 | 实现 DeepSeek Provider | P1 | 1天 |
| 8 | 实现 Custom Provider（自定义 Base URL） | P1 | 0.5天 |
| 9 | 错误处理（网络/API Key 无效/超时） | P1 | 1天 |
| 10 | 写一个"Hello World"级别的 App 内测试 | P2 | 0.5天 |

### 验收
- 用户输入 API Key → 选择 DeepSeek → 聊天 → 流式输出 → 消息保存在本地 → 关闭重新打开消息还在

---

## 第 3-5 周：MVP 1

### 任务清单

| # | 任务 | 优先级 | 预估 |
|---|------|--------|------|
| 1 | CharacterProfile 完整数据模型 | P0 | 1天 |
| 2 | 角色编辑器 UI（表单式） | P0 | 2天 |
| 3 | 3-5 个角色模板（JSON 预设） | P0 | 1天 |
| 4 | MemoryItem 数据模型（semantic + episodic） | P0 | 1天 |
| 5 | 记忆手动添加/编辑/删除 | P0 | 1天 |
| 6 | WorldBookEntry 数据模型 + 简单 CRUD | P0 | 1天 |
| 7 | 世界书关键词触发（初版） | P0 | 1天 |
| 8 | Context Builder v0（固定模板，简单检索） | P0 | 2天 |
| 9 | Token 预算管理（简单版） | P0 | 1天 |
| 10 | BYOK 设置页面 UI | P0 | 1天 |
| 11 | 记忆管理页面 UI | P1 | 1天 |
| 12 | 世界书编辑页面 UI | P1 | 1天 |
| 13 | 角色选择/切换 | P1 | 1天 |
| 14 | Prompt 调优（让角色符合人格） | P1 | 2天 |

### 验收
- 用户可以创建/编辑角色 → 角色回复符合设定
- 手动添加记忆 → 角色在相关话题自然引用
- 世界书关键词触发 → 角色体现设定但不背书
- DeepSeek / OpenAI / 自定义全部可用

---

## 第 6-9 周：MVP 2

### 任务清单

| # | 任务 | 优先级 | 预估 |
|---|------|--------|------|
| 1 | MemoryExtractor 自动抽取引擎 | P0 | 3天 |
| 2 | 抽取 prompt 设计与调优 | P0 | 2天 |
| 3 | MemoryRanker 排序算法 | P0 | 1天 |
| 4 | DecayEngine 衰减引擎 | P1 | 1天 |
| 5 | 记忆合并与矛盾检测 | P1 | 2天 |
| 6 | 情绪记忆 (emotional) 支持 | P1 | 1天 |
| 7 | 关系记忆 (relationship) 支持 | P1 | 1天 |
| 8 | Context Builder v1（动态检索 + 优先级） | P0 | 2天 |
| 9 | Token 预算管理（智能分配版） | P1 | 1天 |
| 10 | WorldBook TriggerEngine 完善（优先级+冷却） | P1 | 1天 |
| 11 | 反思记忆（手动触发版） | P1 | 1天 |
| 12 | 用户消息分析（关键词/实体提取） | P1 | 1天 |
| 13 | 记忆导出功能 | P2 | 1天 |
| 14 | 全面的 prompt 调优 | P1 | 2天 |

### 验收
- 对话后自动抽取记忆（后台异步）
- 记忆有评分，Context Builder 按优先级检索
- 矛盾记忆被标记
- 衰减机制工作：不重要+久未访问的不再被检索
- 角色引用记忆自然（不机械）

---

## 第 10-13 周：MVP 3 + 上线准备

### 任务清单

| # | 任务 | 优先级 | 预估 |
|---|------|--------|------|
| 1 | LifeScheduler 基础实现 | P0 | 2天 |
| 2 | 角色状态解析 + 补算 | P0 | 2天 |
| 3 | 回复延迟策略 | P0 | 1天 |
| 4 | MoodState 基础实现 | P1 | 1天 |
| 5 | RealismEngine v1 | P0 | 2天 |
| 6 | 聊天页状态栏 UI | P0 | 1天 |
| 7 | 角色状态页面 UI | P1 | 1天 |
| 8 | App Icon + 启动画面 | P0 | 1天 |
| 9 | App Store 截图 + 描述文案 | P0 | 2天 |
| 10 | 隐私政策 + 用户协议 | P0 | 1天 |
| 11 | 全面测试 + Bug 修复 | P0 | 3天 |
| 12 | TestFlight 分发测试 | P0 | 1天 |
| 13 | App Store 提交 | P0 | 1天 |

### 验收
- 角色有基本时间流（早/中/晚状态不同）
- 角色在"上课/工作"时延迟回复
- 回复长度自然变化（不总是长篇）
- 角色有基本边界（可以表达不确定/疲惫）
- App Store 审核通过 🚀

---

## 不建议在第一阶段做的

```
❌ 云端同步 / Cloud Life Mode（等核心体验验证后再做）
❌ 主动消息（MVP 3 之后再考虑）
❌ 多角色关系图
❌ 角色市场
❌ iPad / Apple Watch 适配
❌ 本地 embedding（用 API 的 embedding 或纯关键词检索）
❌ 复杂的 UI 动画
❌ 多语言支持（先做中文）
❌ 复杂的数据分析/统计
```

## 关键里程碑

```
Week 2  ── MVP 0 完成：可以聊天了
Week 5  ── MVP 1 完成：角色有基本人格和记忆了
Week 9  ── MVP 2 完成：记忆系统可用了
Week 13 ── MVP 3 完成 + App Store 提交
Week 14 ── 🚀 上线（理想情况）
Week 15+ ── 收集用户反馈，迭代
```

## 每日开发节奏建议（独立开发者）

```
上午（2-3h）：写核心逻辑（引擎层代码）
下午（2-3h）：写 UI + 集成
晚上（1-2h）：测试 + 调 prompt + 整理文档
```

## 技术决策备忘

- **数据库**：GRDB。理由：复杂查询、成熟、类型安全。不用 SwiftData（太新，不够灵活）。
- **Provider 抽象**：协议 + 工厂模式。每个 Provider 独立实现 LLMProvider 协议。
- **异步**：Swift Concurrency (async/await)。所有 API 调用和数据库操作都在后台 actor。
- **UI 架构**：MVVM。每个页面一个 ViewModel，通过 @ObservableObject 绑定。
- **记忆抽取**：异步 Task，不阻塞 UI。抽取结果写入数据库后触发 UI 刷新。
- **没有响应式框架**（Combine/RxSwift）。Swift Concurrency 足够。
