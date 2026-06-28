# 05 — 记忆系统设计（核心）

## 5.1 设计目标

记忆系统不是聊天记录搜索。它模拟人类记忆的关键特征：

1. **层次性**：有短期记忆、事件记忆、事实记忆、情绪记忆，不是平的
2. **选择性**：重要的记住，琐碎的忘记
3. **重构性**：回忆是重建而非精确回放
4. **衰减性**：记忆随时间衰退
5. **可纠正性**：可以被纠正和更新
6. **关联性**：记忆之间互相关联，一个触发另一个
7. **情绪性**：强烈情绪的记忆更牢固

## 5.2 记忆层级总览

```
Layer 0: Raw Messages ─────────── 完整对话记录（仅做证据，不做检索）
    │
    ├── 抽取 ──→ Layer 1: Short-term Memory ── 最近 N 轮对话
    │                                         │
    ├── 抽取 ──→ Layer 2: Episodic Memory ──── "发生过什么"
    │           (事件记忆)                    │
    ├── 抽取 ──→ Layer 3: Semantic Memory ──── "知道了什么"
    │           (事实记忆)                    │
    ├── 抽取 ──→ Layer 4: Emotional Memory ─── "感受如何"
    │           (情绪记忆)                    │
    ├── 抽取 ──→ Layer 5: Relationship Memory─ "关系如何变化"
    │           (关系记忆)                    │
    ├── 整理 ──→ Layer 6: Reflection Memory ── 周期性反思
    │           (反思记忆)                    │
    ├── 整理 ──→ Layer 7: Topic Documents ──── 按主题整理
    │           (主题文档)                    │
    ├── 关联 ──→ Layer 8: World-linked Memory─ 与世界书关联
    │           (世界关联记忆)                │
    └── Layer 9: Correction Memory ────────── 用户纠正记录
                (修正记忆)

Layer 10: Forgetting/Decay ─────── 横切所有层的遗忘机制
```

## 5.3 MemoryItem 通用数据结构

```swift
// GRDB Record - 所有记忆层的统一数据结构
struct MemoryItem: Codable, FetchableRecord, PersistableRecord {
    // 基础标识
    var id: String                  // UUID
    var characterId: String         // 所属角色
    var userId: String?             // 所属用户（多用户场景，MVP 为 nil）

    // 记忆类型
    var type: MemoryType            // 见枚举

    // 内容
    var content: String             // 自然语言描述的记忆内容
    var summary: String?            // 简短摘要（用于列表展示和快速检索）

    // 来源追溯（重要！防止"我记得"但无证据）
    var sourceMessageIds: [String]  // 来源于哪些消息 ID
    var extractionMethod: ExtractionMethod
    var extractionModel: String?    // 用哪个模型抽取的
    var extractionPromptUsed: String? // 抽取时用的 prompt（调试用）

    // 评分系统
    var confidence: Double          // 置信度 0.0 - 1.0
    var importance: Double          // 重要性 0.0 - 1.0
    var emotionalValence: Double?   // 情绪效价 -1.0(负面) 到 +1.0(正面)
    var emotionalIntensity: Double? // 情绪强度 0.0 - 1.0
    var relationshipImpact: Double? // 对关系的影响 -1.0 到 +1.0

    // 时间
    var createdAt: Date
    var updatedAt: Date
    var lastAccessedAt: Date
    var eventDate: Date?            // 事件发生的实际时间

    // 遗忘
    var decayScore: Double          // 当前衰减分数 0.0(完全遗忘) - 1.0(完全清晰)
    var decayRate: Double           // 衰减速率（每日衰减比例）

    // 一致性
    var contradictionGroupId: String?  // 如果矛盾，加入矛盾组
    var status: MemoryStatus           // active/superseded/deleted/user_corrected/dormant

    // 检索
    var tags: [String]              // 标签
    var keywords: [String]          // 关键词
    var embeddingRef: String?       // 向量嵌入引用

    // 关联
    var relatedMemoryIds: [String]  // 关联的其他记忆 ID
    var worldBookEntryIds: [String] // 关联的世界书条目 ID
    var topicDocumentId: String?    // 所属主题文档 ID

    // 用户控制
    var isUserEditable: Bool        // 用户是否可编辑
    var isUserVisible: Bool         // 用户是否可见
    var userEditedContent: String?  // 用户编辑后的版本
}

// MARK: - 枚举类型

enum MemoryType: String, Codable {
    case episodic         // 事件记忆："发生过什么"
    case semantic         // 事实记忆："知道了什么"
    case emotional        // 情绪记忆："感受如何"（角色第一人称）
    case relationship     // 关系记忆："关系如何变化"
    case reflection       // 反思记忆：周期性总结
    case topicDocument    // 主题文档：跨时间主题整理
    case worldLinked      // 世界关联记忆：与世界书条目关联
    case correction       // 修正记忆：用户纠正记录
}

enum MemoryStatus: String, Codable {
    case active           // 正常使用中
    case superseded       // 被更准确的信息替代
    case deleted          // 用户删除（软删除）
    case userCorrected    // 用户纠正过
    case dormant          // 因衰减而休眠（decayScore < 0.3）
}

enum ExtractionMethod: String, Codable {
    case autoExtract          // 自动抽取
    case manual               // 用户手动添加
    case userEdit             // 用户编辑后
    case reflection           // 反思生成
    case worldBookLink        // 从世界书关联生成
    case systemCorrection     // 系统纠错后
    case import_              // 从外部导入
}
```

## 5.4 各层记忆详细设计

### 5.4.1 Raw Messages（原始消息）

**职责**：完整保存所有对话，作为记忆的证据链。不做语义检索。

```swift
struct Message: Codable {
    var id: String
    var characterId: String
    var role: MessageRole        // user / character / system
    var content: String
    var timestamp: Date
    var messageType: MessageType // normal / proactive / system_notification
    var tokenCount: Int?
    var modelUsed: String?
    var responseLatency: TimeInterval?
    var proactiveTrigger: String? // 如果是主动消息，记录触发原因
}
```

**写入规则**：所有消息默认保存。不做自动删除。
**不写入**：无（完整性要求全量保存）。
**检索方式**：仅按时间范围 + character_id 查询，不做语义检索。

### 5.4.2 Short-term Memory（短期上下文）

**职责**：最近的对话上下文，直接进入 prompt。

**不需要独立存储**——直接从 Raw Messages 取最近 N 条消息，N 由 token 预算动态决定。通常保留 2000-4000 token 的最近对话。

**"短期"的定义**：不是按时间，而是按 token 预算。概念上约等于"当前会话的最近几轮"。

### 5.4.3 Episodic Memory（事件记忆）

**职责**：记录"发生过什么"——用户和角色之间有意义的具体交互事件。

**应该写入**：
- ✅ 用户和角色共同经历的有意义对话（深度长谈、解决了问题）
- ✅ 用户分享了个人重要信息（通过考试、换工作、旅行、生病）
- ✅ 对话中出现强烈情绪
- ✅ 对话主题发生显著转变
- ✅ 用户和角色一起完成了一件事（哪怕只是聊天中一起策划了某事）

**不应该写入**：
- ❌ 日常寒暄（"吃了吗""嗯""好的"）
- ❌ 纯信息查询（"今天天气怎么样"——这不构成事件）
- ❌ 单轮无深度对话
- ❌ 与之前事件完全重复的内容

**示例**：
```
content: "2024年6月15日下午，用户告诉角色他通过了研究生入学考试。用户情绪非常兴奋，
         角色表达了真诚的祝贺。用户说这对他意义重大，因为他为此准备了两年。"
confidence: 0.95
importance: 0.85
emotionalValence: 0.9
emotionalIntensity: 0.8
eventDate: 2024-06-15T14:30:00Z
decayRate: 0.005  // 重要事件，几乎不忘
```

### 5.4.4 Semantic Memory（事实记忆）

**职责**：记录"知道了什么"——关于用户、关于角色自身、关于两人关系的稳定事实。

**应该写入**：
- ✅ 用户明确陈述的个人信息（城市、职业、学校、爱好）
- ✅ 经过多次确认的稳定信息
- ✅ 用户纠正过的信息（更新旧记忆）
- ✅ 角色在与用户互动中形成的对用户的理解

**不应该写入**：
- ❌ 一次性提到的、可能不准确的信息（初次提到标记低 confidence，多次确认后提高）
- ❌ 推理得出的、未经用户确认的信息
- ❌ 敏感个人信息（真实姓名、地址、电话——除非角色设定需要且用户同意）

**示例**：
```
content: "用户在北京工作，是后端开发工程师，主要使用 Go 和 Python。在字节跳动上班。"
confidence: 0.90
importance: 0.70
decayRate: 0.002  // 事实信息衰减极慢
```

### 5.4.5 Emotional Memory（情绪记忆）

**职责**：记录角色对特定事件的情绪反应——**必须是角色第一人称视角**。

```
✅ 正确格式："角色感到被用户信任，这让角色很温暖"
❌ 错误格式："用户信任角色"（这是事实记忆的范畴）

✅ "角色因为帮不上用户的忙而感到沮丧和内疚"
❌ "用户遇到了一个困难"（这是事件记忆）
```

**不写入**：中性互动、轻微情绪波动、不符合角色人格的情绪（冷淡型角色不应产生大量温暖记忆）

### 5.4.6 Relationship Memory（关系记忆）

**职责**：记录用户与角色之间关系的关键变化点——关系"转折点"。

**示例**：
```
content: "用户第一次向角色倾诉了工作上的深层压力，角色感到被深深信任。
         这是两人关系从普通朋友向熟悉朋友转变的标志性时刻。"
importance: 0.80
relationshipImpact: 0.4  // 正向关系推动
```

**不写入**：没有关系变化的日常互动。

### 5.4.7 Reflection Memory（反思记忆）

**职责**：定期对过去一段时间进行"反思"，生成更高层次的总结理解。

**触发时机**：每 20 轮对话 / 每天结束 / 每周结束 / 用户手动触发。

**反思 Prompt 模板**：
```
基于以下最近的记忆条目，请以角色的第一人称回答：
[最近 20 条 Episodic + Emotional + Relationship Memory]

1. 这段时间和用户的互动中，最重要的事是什么？
2. 我对用户有了什么新的了解？
3. 我们的关系有什么变化？
4. 有没有应该记住但没被记录的事？
5. 有没有矛盾的信息需要澄清？
```

### 5.4.8 Topic Documents（主题文档）

**职责**：将分散在不同时间点的相关记忆按主题整理成连贯文档。

**与 Reflection 的区别**：Reflection 按时间段反思，Topic Document 按主题跨时间整理。

**主题类型**：
- `user_life_work`：用户的工作
- `user_life_study`：用户的学习/考试
- `user_life_health`：用户的健康
- `user_life_family`：用户的家庭
- `shared_project`：共同项目
- `shared_interest`：共同兴趣
- `character_self`：角色的自我认知
- `relationship_history`：关系历程

**示例**：
```
type: topicDocument
topic: user_life_work
content: "用户在字节跳动担任后端开发（2024年3月至今）。之前在创业公司2年。
         目前在做的项目与云原生相关。工作满意程度中等，有时加班严重。
         最近在考虑职业方向。用户对技术深度有追求，不喜欢重复性工作。"
sourceMessageIds: [msg_1, msg_5, msg_12, msg_23]
lastUpdated: 2024-06-15
```

### 5.4.9 World-linked Memory（世界关联记忆）

**职责**：把"角色在互动中经历的"和"世界书中的设定"连接起来。

**示例**：
- 世界书设定："霍格沃茨有格兰芬多、赫奇帕奇、拉文克劳、斯莱特林四个学院"
- 角色在对话中被分到格兰芬多 → 生成 World-linked Memory："角色被分到了格兰芬多学院"
- 这条记忆关联到世界书条目 `world_hogwarts_houses`

### 5.4.10 Correction Memory（修正记忆）

**职责**：用户纠正记忆的记录，确保系统不重复犯同样错误。

```swift
// 当用户纠正时：
// 1. 原记忆状态改为 superseded
// 2. 新建 Correction Memory，关联原记忆
// 3. 正确事实写入新的 Semantic Memory
// 4. Correction Memory.isPermanent = true 表示永不自动覆盖
```

### 5.4.11 Forgetting / Decay（遗忘与衰减）

**衰减公式**：

```
decayScore(t) = decayScore(t0) × e^(-decayRate × days_since_last_access)

调整因子：
- importance 越高 → decayRate 乘 0.3（重要的事忘得慢）
- emotionalIntensity 越高 → decayRate 乘 0.5（情绪强的事忘得慢）
- 最近访问过 → decayScore 暂时 +0.1
- 被 reflection 引用过 → decayRate 乘 0.7
- 用户标记为"重要" → decayRate 强制为 0（永不忘）
- 矛盾信息出现 → 旧记忆 decayRate 乘 2.0（加速遗忘）
- 用户纠错 → 原记忆立即 decayScore 归 0
```

**遗忘不等于删除**：
- decayScore < 0.3：不再主动检索，但数据保留（status → dormant）
- decayScore < 0.1：提示用户可清理
- 用户显式删除：软删除或硬删除

## 5.5 记忆抽取引擎

### 自动抽取流程

```
对话结束
    │
    ▼
检查是否触发抽取：
  - 距离上次抽取已过 N 轮（默认 5 轮）
  - 或对话中出现明显的"事件边界"（话题大转变、强烈情绪、用户说"我有个事想说"）
  - 或用户手动触发
    │
    ▼
组装抽取 prompt → 调用模型（用用户配置的 API）→ 解析结果
    │
    ▼
对每条抽取结果：
  1. 检查与已有记忆的矛盾（语义相似度 > 0.85 的同类型记忆）
  2. 判断是更新、矛盾还是新记忆
  3. 如果是更新：旧记忆 superseded，新记忆 active
  4. 如果是矛盾：加入矛盾组，通知用户
  5. 如果是新记忆：直接写入
  6. 设置 source_message_ids
  7. 计算初始 decayRate
```

### 抽取 Prompt 设计

```
System:
你是 {character_name} 的记忆抽取器。请从以下对话中提取值得长期记住的信息。

抽取规则：
- 只抽取有意义的信息，不抽取日常寒暄
- 每条记忆必须有明确的来源（对话中的具体内容）
- 给出置信度：0.5=可能但不确定，0.9=非常确定
- 给出重要性：0.3=琐碎但可能有意义，0.9=非常重要必须记住

抽取类型：
1. episodic: 发生过的重要事件
2. semantic: 关于用户或角色的新事实
3. emotional: 角色对此事件的感受（角色第一人称）
4. relationship: 关系中值得记住的变化

不要抽取：
- "吃了吗""嗯""好的"等日常寒暄
- 不确定的推测
- 敏感个人信息（密码、地址等）

User:
[最近 N 轮对话]

输出 JSON 格式：
[{"type":"...", "content":"...", "confidence":0.X, "importance":0.X,
  "emotionalValence":0.X, "emotionalIntensity":0.X, "relationshipImpact":0.X}]
```

### 抽取成本控制

```
每次抽取消耗 token ≈ 抽取 prompt(200) + 最近对话(2000) + 输出(500) ≈ 2700 token
按 DeepSeek 价格 ≈ ¥0.004/次
假设每天 20 轮对话，抽取 4 次 ≈ ¥0.016/天 ≈ ¥0.5/月

结论：抽取成本极低，用户几乎无感知
```

## 5.6 记忆矛盾检测与处理

```
新记忆到达
    │
    ▼
对同类型、同 topic 的已有 active 记忆做语义相似度检查
    │
    ├── 相似度 < 0.5：无关联，独立保存
    ├── 相似度 0.5-0.85：可能相关，标记 relatedMemoryIds
    └── 相似度 > 0.85：可能矛盾或更新
            │
            ▼
        调用轻量判断 prompt：
        "旧记忆：{A}。新信息：{B}。它们是：(a)更新关系 (b)矛盾 (c)互补？"
            │
            ├── 更新：旧→superseded，新→active，设置 relatedMemoryIds
            ├── 矛盾：都入同一 contradictionGroupId，通知用户裁决
            └── 互补：都 active，互相引用 relatedMemoryIds
```

**用户体验**：在 Memory 管理页面，矛盾组用黄色标记显示，用户可以：
- 选择保留哪一个
- 手动合并
- 忽略矛盾（两个都保留）

## 5.7 记忆检索（供 Context Builder 使用）

### 检索策略（每次对话前执行）

```
输入：
  - 用户当前消息
  - 角色 ID
  - 当前时间

检索步骤：
1. 提取用户消息中的关键词和实体
2. 生成用户消息的 embedding（用 API 或本地模型）
3. 多路召回：
   a. 关键词匹配（tags, keywords 字段）
   b. 语义相似度（embedding cosine similarity）
   c. 最近访问（lastAccessedAt 排序）
   d. 高重要性（importance > 0.7）
   e. 关联当前世界书触发条目
4. 合并去重
5. 按优先级排序
6. 根据 token 预算截断

默认每条检索上限：
  Episodic:     5 条
  Semantic:     5 条
  Emotional:    3 条
  Relationship: 2 条
  Reflection:   2 条
  Topic:        2 条
  World-linked: 3 条
  Correction:   全部（数量少，但确保被尊重）
  ────────────────────
  共计约 22 条，约 1500-2500 tokens
```

## 5.8 记忆的 GRDB/SQLite 实现建议

```swift
// 在 AppDelegate 中设置数据库
try dbPool.write { db in
    try db.create(table: "memoryItem") { t in
        t.column("id", .text).primaryKey()
        t.column("characterId", .text).notNull().indexed()
        t.column("type", .text).notNull().indexed()
        t.column("content", .text).notNull()
        t.column("summary", .text)
        t.column("confidence", .double).notNull()
        t.column("importance", .double).notNull()
        t.column("emotionalValence", .double)
        t.column("emotionalIntensity", .double)
        t.column("relationshipImpact", .double)
        t.column("createdAt", .datetime).notNull().indexed()
        t.column("updatedAt", .datetime).notNull()
        t.column("lastAccessedAt", .datetime).notNull()
        t.column("eventDate", .datetime)
        t.column("decayScore", .double).notNull().defaults(to: 1.0)
        t.column("decayRate", .double).notNull().defaults(to: 0.01)
        t.column("contradictionGroupId", .text)
        t.column("status", .text).notNull().defaults(to: "active").indexed()
        t.column("topicDocumentId", .text)
        t.column("isUserEditable", .boolean).notNull().defaults(to: true)
        t.column("isUserVisible", .boolean).notNull().defaults(to: true)
        t.column("userEditedContent", .text)
        // JSON 编码的数组字段
        t.column("sourceMessageIds", .text)       // JSON array
        t.column("tags", .text)                   // JSON array
        t.column("keywords", .text)               // JSON array
        t.column("relatedMemoryIds", .text)       // JSON array
        t.column("worldBookEntryIds", .text)      // JSON array
        t.column("embeddingRef", .text)
        t.column("extractionMethod", .text).notNull()
        t.column("extractionModel", .text)
    }
    // 复合索引：按角色+类型+状态查询
    try db.create(index: "idx_memory_lookup",
                  on: "memoryItem",
                  columns: ["characterId", "type", "status"])
    // 按衰减分数索引（用于清理）
    try db.create(index: "idx_memory_decay",
                  on: "memoryItem",
                  columns: ["decayScore", "lastAccessedAt"])
}
```

## 5.9 记忆可视化（用户界面）

**原则**：记忆管理页面可以展示技术细节，但 Chat 页面绝不能暴露检索痕迹。

| 场景 | 展示方式 |
|------|---------|
| 记忆列表页 | 展示 type, content, confidence, importance, 来源消息预览 |
| 记忆详情页 | 完整 content, 所有元数据, 关联记忆链接, 来源消息引用 |
| 矛盾标记 | 黄色高亮 + "可能有矛盾" 标签 |
| Chat 页面 | **不暴露任何记忆检索信息**。角色自然引用——"你之前说过..." |

## 5.10 防止角色"机械背诵记忆"

这是关键设计。角色不应该说"根据我的记忆数据库，你在……"。

**实现方式**：

1. **prompt 层面**：在 System Prompt 中指令——"引用记忆时，用自然的'记得'、'你之前说过'、'上次我们聊到'等方式，不要用'根据记录''根据记忆条目'等机械表达"
2. **格式层面**：记忆以自然语言存储（"用户在北京工作"），不是以字段-值存储
3. **confidence 门槛**：confidence < 0.6 的记忆不进入 prompt——角色自动"不确定"，会说"你是不是说过……"而不是"我记得……"
4. **溯源要求**：如果角色引用了某条记忆但 confidence < 0.7，prompt 指令要求角色使用"我印象中""好像""你是不是提过"等不确定表达
