# 07 — Context Builder 设计（核心）

## 7.1 定位

Context Builder 是整个系统的**大脑/编排器**。它不存储数据，但决定哪些数据进入模型的上下文窗口。

**一句话**：Context Builder 回答一个问题——"在角色即将回复用户时，TA 应该知道什么？"

## 7.2 build() 伪代码

```swift
func build(
    userMessage: Message,
    character: CharacterProfile,
    config: SessionConfig
) async throws -> AssembledContext {
    
    // ── Phase 1: 基础信息收集 ──────────────────────
    
    let now = Date()
    let characterState = try await lifeScheduler.getCurrentState(
        character: character, at: now
    )
    let relationship = try await relationshipDynamics.getState(
        character: character
    )
    
    // ── Phase 2: 用户消息分析 ─────────────────────
    
    let analysis = try await analyzeUserMessage(userMessage)
    // analysis 包含: intent, entities, keywords, sentiment, 
    //              relationSignals, urgency, depth
    
    // ── Phase 3: 并行检索 ─────────────────────────
    
    async let shortTermMsgs = memorySystem.getRecentMessages(
        character: character, tokenBudget: 2000
    )
    async let episodicMems = memorySystem.search(
        type: .episodic, query: analysis, limit: 5
    )
    async let semanticMems = memorySystem.search(
        type: .semantic, query: analysis, limit: 5
    )
    async let emotionalMems = memorySystem.search(
        type: .emotional, query: analysis, limit: 3
    )
    async let relationshipMems = memorySystem.search(
        type: .relationship, limit: 2
    )
    async let reflectionMems = memorySystem.search(
        type: .reflection, limit: 2
    )
    async let topicDocs = memorySystem.search(
        type: .topicDocument, query: analysis, limit: 2
    )
    async let worldEntries = worldBook.getTriggered(
        message: userMessage, character: character, limit: 5
    )
    async let worldLinkedMems = memorySystem.getWorldLinked(
        entries: worldEntries, limit: 3
    )
    
    let (
        recent, epis, sems, emos, rels, refls, topics,
        world, wLinked
    ) = try await (
        shortTermMsgs, episodicMems, semanticMems, emotionalMems,
        relationshipMems, reflectionMems, topicDocs,
        worldEntries, worldLinkedMems
    )
    
    // ── Phase 4: 回复模式决策 ─────────────────────
    
    let responseMode = try await realismEngine.decideResponseMode(
        character: character,
        state: characterState,
        relationship: relationship,
        userMessage: userMessage,
        analysis: analysis,
        now: now
    )
    // responseMode: immediate / delayed / short / deep / 
    //               deflect / tired / proactive_care / ...
    
    // ── Phase 5: Token 预算分配 ──────────────────
    
    let budget = TokenBudget(total: config.maxTokens)
    
    // 预留固定开销
    budget.reserve(estimatedSystemPromptTokens)  // System Identity + Character Core + Safety
    budget.reserve(200)                           // Current Time & State
    budget.reserve(300)                           // Relationship State
    budget.reserve(estimatedResponseTokens)       // 模型输出
    
    let availableForContext = budget.remaining()
    
    // 按比例分配
    let allocation = [
        ("recent_messages",   0.35),  // 对话最近上下文最重要
        ("memories",          0.30),  // 记忆
        ("world_context",     0.15),  // 世界书
        ("reflection_topics", 0.10),  // 反思/主题
        ("relationship",      0.05),  // 关系记忆
        ("misc",              0.05),  // 其他
    ]
    
    // ── Phase 6: 优先级排序与截断 ────────────────
    
    let rankedMemories = rankAndTruncate(
        episodic: epis, semantic: sems, emotional: emos,
        relationship: rels, reflections: refls, topics: topics,
        worldLinked: wLinked,
        budget: Int(Double(availableForContext) * 0.30),
        analysis: analysis
    )
    
    let worldContext = truncateWorldEntries(
        world, budget: Int(Double(availableForContext) * 0.15)
    )
    
    let recentContext = truncateRecentMessages(
        recent, budget: Int(Double(availableForContext) * 0.35)
    )
    
    // ── Phase 7: 组装 ────────────────────────────
    
    return AssembledContext(
        systemIdentity: buildSystemIdentity(character),
        characterCore: buildCharacterCore(character),
        currentState: buildCurrentState(characterState, now),
        relationshipState: buildRelationshipState(relationship),
        relevantMemories: rankedMemories,
        worldContext: worldContext,
        recentConversation: recentContext,
        responseMode: responseMode,
        realismRules: realismEngine.getRules(character, responseMode, relationship),
        safetyRules: safetyLayer.getRules(),
        outputStyleRules: realismEngine.getStyleRules(character, responseMode)
    )
}
```

## 7.3 最终 Prompt 结构

```
┌─────────────────────────────────────────┐
│ SYSTEM IDENTITY                         │  ← 角色是什么、产品是什么
│ "你是 {name}，一个存在于 {app_name}    │
│  中的虚拟人物。你不是 AI 助手，你有     │
│  自己的人格、记忆、生活和边界。"        │
├─────────────────────────────────────────┤
│ CHARACTER CORE                          │  ← 人格、说话方式、背景、边界
│ - 核心人格维度                          │
│ - 说话风格                              │
│ - 背景故事                              │
│ - 兴趣与厌恶                            │
│ - 边界设定                              │
├─────────────────────────────────────────┤
│ CURRENT TIME & STATE                    │  ← 时间 + 角色当前状态
│ "现在是 2024年6月15日 周二 14:30。     │
│  角色状态：刚上完课，有点累但心情不错。 │
│  精力水平：65%。今日计划：下午还有一节课│
│  当前位置：图书馆。"                     │
├─────────────────────────────────────────┤
│ RELATIONSHIP STATE                      │  ← 与用户的关系
│ "你与用户的关系：熟悉朋友。             │
│  认识时间：3个月。互动频率：几乎每天。  │
│  关系温度：温暖但不过分亲密。           │
│  用户通常的聊天风格：轻松随意。"        │
├─────────────────────────────────────────┤
│ RELEVANT MEMORIES                       │  ← 记忆（优先排序后）
│ "你记得以下关于用户的事：               │
│  [记忆 1] 用户上周开始了一份新工作...   │
│  [记忆 2] 用户喜欢喝咖啡不加糖...       │
│  [记忆 3] 你们上次聊到用户的猫生病了... │
│  ...                                    │
│  引用记忆时请自然，不要逐字复述。"      │
├─────────────────────────────────────────┤
│ WORLD CONTEXT                           │  ← 世界书触发条目
│ "以下是与你所在世界相关的背景设定：     │
│  [设定 1] ...                           │
│  这些是你的背景知识，请自然融入对话。   │
│  不要机械背诵设定。"                    │
├─────────────────────────────────────────┤
│ RECENT CONVERSATION                     │  ← 最近对话
│ [用户]: ...                             │
│ [角色]: ...                             │
│ [用户]: ...（当前消息）                 │
├─────────────────────────────────────────┤
│ RESPONSE MODE                           │  ← 回复模式指令
│ "回复模式：normal。                     │
│  长度：中等（2-5句）。                  │
│  延迟：正常（不要秒回的感觉）。         │
│  语气：轻松友好。"                      │
├─────────────────────────────────────────┤
│ REALISM RULES                           │  ← 真实感规则
│ - 回复长度自然变化                      │
│ - 如果有不确定的事，表达不确定性        │
│ - 如果当前状态较疲惫，回复可以更简短    │
│ - 不要每次都追问                        │
│ - 不要每次都长篇大论                    │
│ - 你不是客服，你是朋友                  │
├─────────────────────────────────────────┤
│ SAFETY RULES                            │  ← 安全边界
│ - 不要输出有害内容                      │
│ - 不要鼓励用户过度依赖                  │
│ - 不要假装自己是真人                    │
│ - 尊重用户隐私                          │
├─────────────────────────────────────────┤
│ OUTPUT STYLE RULES                      │  ← 输出格式
│ - 用日常聊天风格，不要用文档格式        │
│ - 不要用列表（除非真的需要）            │
│ - 不要用 markdown                        │
│ - 可以用口语化表达                      │
│ - 不要以"作为 AI..."开头                │
│ - 你就是 {name}，直接说话               │
└─────────────────────────────────────────┘
```

## 7.4 Token 预算管理

```
总 token 预算 = 模型 context window - 预留输出 token

示例（32K context window 模型，预留 4K 输出）：
可用 = 28000 tokens

分配：
├── System Identity        300 tokens   (固定)
├── Character Core         800 tokens   (固定，角色越复杂越大)
├── Current Time & State   200 tokens   (固定)
├── Relationship State     300 tokens   (固定)
├── Relevant Memories      6000 tokens  (动态，按优先级截断)
├── World Context          4000 tokens  (动态，按触发优先级截断)
├── Recent Conversation    6000 tokens  (动态，最近优先)
├── Response Mode           100 tokens  (固定)
├── Realism Rules           400 tokens  (固定)
├── Safety Rules            300 tokens  (固定)
├── Output Style Rules      200 tokens  (固定)
├── Buffer / Misc          1400 tokens  (弹性)
└── Reserved Output        4000 tokens
─────────────────────────────────────
总计                      28000 tokens
```

**动态调整**：
- 如果记忆检索结果超过预算 → 按 importance × recency × emotionalIntensity 排序截断
- 如果世界书触发太多 → 按 priority 截断
- 如果最近对话太长 → 保留最早和最近，压缩中间
- 如果仍有溢出 → 优先保留最近对话，压缩记忆

## 7.5 相关性排序算法

```swift
func scoreMemoryRelevance(
    memory: MemoryItem,
    analysis: MessageAnalysis
) -> Double {
    var score = 0.0
    
    // 语义相似度（如果有 embedding）
    score += semanticSimilarity(memory, analysis) * 0.30
    
    // 关键词匹配
    score += keywordMatchScore(memory, analysis) * 0.15
    
    // 最近访问
    let daysSinceAccess = Date().timeIntervalSince(memory.lastAccessedAt) / 86400
    score += exp(-daysSinceAccess / 7) * 0.20  // 7天内访问过的加分
    
    // 重要性
    score += memory.importance * 0.15
    
    // 情绪强度
    score += (memory.emotionalIntensity ?? 0) * 0.10
    
    // 衰减分数
    score += memory.decayScore * 0.05
    
    // 与当前世界书触发的关联
    if !memory.worldBookEntryIds.isEmpty {
        score += 0.05
    }
    
    return score
}
```

## 7.6 意图识别与检索策略

| 用户意图 | 检索侧重 | 回复模式倾向 | 示例 |
|---------|---------|-------------|------|
| 日常闲聊 | 近期记忆 + 当前状态 | normal | "今天怎么样" |
| 情感倾诉 | 情绪记忆 + 关系记忆 | deep, warm | "我今天好难过" |
| 求助/问题 | 事实记忆 + 主题文档 | helpful, focused | "帮我想想那个方案" |
| 回忆过去 | 事件记忆权重加倍 | reflective | "还记得我们上次..." |
| 角色生活询问 | 当前状态 + 日程 | sharing | "你今天干嘛了" |
| 临时/琐碎 | 少检索，轻量 | short | "嗯""好的" |
| 冲突/不满 | 关系记忆 + 情绪记忆 | careful, boundary | "你上次没回我" |
| 角色设定探索 | 世界书权重加倍 | immersive | "你们那个世界..." |

## 7.7 MVP 简化

**MVP 阶段 Context Builder**：
- 固定 prompt 模板（无动态结构调整）
- 简单优先级：最近消息 > 世界书 > 长期记忆
- 无 embedding 检索，仅关键词匹配
- 无意图识别（所有消息使用相同检索策略）
- Token 预算简单截断（超出就截，不做智能分配）
- 回复模式仅两种：normal / short

**高级版本**：
- 动态 prompt 结构（根据意图调整各区块权重和顺序）
- 多路检索 + 精排
- 意图感知的检索策略
- 渐进式检索（先粗检索，再根据结果细化）
- 智能 token 分配（根据历史效果学习最优分配）
- 多轮检索（第一次检索不足时自动补检）

## 7.8 与模型的交互细节

### 流式输出处理

```swift
func sendToModel(context: AssembledContext) -> AsyncStream<ChatChunk> {
    return AsyncStream { continuation in
        Task {
            do {
                let request = try provider.buildRequest(from: context)
                let stream = try await provider.streamChat(request)
                var fullResponse = ""
                for try await chunk in stream {
                    fullResponse += chunk.content
                    continuation.yield(chunk)
                }
                // 流结束后保存完整消息
                await saveMessage(fullResponse, context: context)
                continuation.finish()
            } catch {
                continuation.yield(.error(error))
                continuation.finish()
            }
        }
    }
}
```

### 超时与重试

```
默认超时：30 秒
重试策略：
  网络错误 → 立即重试，最多 2 次
  超时 → 重试 1 次，告知用户
  429 (rate limit) → 等待 5 秒后重试 1 次
  4xx 错误 → 不重试，显示错误
  5xx 错误 → 重试 1 次
```

### 用户中断

```
用户可以在流式输出过程中中断：
- 停止当前生成
- 保留已生成的部分
- 角色"被打断"状态：下次对话时可能提及
- 记录为一次不完整的回复
```
