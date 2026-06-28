# 06 — 世界书设计（核心）

## 6.1 世界书 vs 记忆的严格区分

这是产品设计中最容易混淆的地方，必须严格区分：

| 维度 | 世界书 | 记忆系统 |
|------|--------|---------|
| **是什么** | 世界本来是什么样的 | 角色经历过什么 |
| **来源** | 用户显式定义/导入 | 对话中自动/半自动抽取 |
| **修改** | 用户手动编辑 | 系统自动更新 + 用户纠正 |
| **触发** | 关键词/向量匹配（被动） | 相关性 + 时间 + 重要性 |
| **遗忘** | 不遗忘（除非用户删除） | 有遗忘曲线 |
| **范围** | 世界观全局 | 角色个人经历 |
| **权威性** | 高（角色应遵守但不机械背诵） | 中（可能不准确，有 confidence） |

**关键边界规则**：
- 角色在对话中产生的新事实 → 写入记忆，不是世界书
- 如果记忆反过来改变世界设定 → 需要用户显式确认，走"世界状态更新"流程
- 用户临时口嗨不永久改写世界设定

## 6.2 世界书条目类型

```
1. Character Entry    — 人物条目（世界观中的其他人物）
2. Location Entry     — 地点条目
3. Timeline Entry     — 时间线条目
4. Relationship Entry — 关系条目（世界设定中的人物关系，非用户与角色的关系）
5. Rule Entry         — 世界规则（魔法规则、科技设定、社会制度）
6. Object Entry       — 重要物品
7. Organization Entry — 组织/势力/团体
8. Style Entry        — 语言风格/叙述风格
9. Project Entry      — 项目资料/任务说明
10. Canon Entry       — 正史设定（不可被对话改变）
11. Non-canon Entry   — 非正史设定（AU/if线）
12. User Custom Entry — 用户自定义类型
```

## 6.3 WorldBookEntry 数据结构

```swift
struct WorldBookEntry: Codable, FetchableRecord, PersistableRecord {
    // 基础
    var id: String                  // UUID
    var scope: WorldBookScope       // global / character / session
    var characterId: String?        // 如果 scope=character，关联哪个角色
    var title: String               // 条目标题
    var content: String             // 条目内容（自然语言）

    // 触发
    var keywords: [String]          // 触发关键词
    var aliases: [String]           // 别名（同一事物的不同称呼）
    var activationRules: String?    // 触发规则（复杂条件，如 "只在夜间触发"）
    var priority: Int               // 优先级 0-100（越高越优先展示）
    var cooldownSeconds: Int?       // 冷却时间（避免频繁触发）

    // 分类
    var entryType: WorldBookEntryType
    var canonLevel: CanonLevel      // 正史层级
    var source: String?             // 来源说明

    // 状态
    var enabled: Bool               // 是否启用
    var createdAt: Date
    var updatedAt: Date
    var embeddingRef: String?       // 向量嵌入引用

    // 关联
    var parentEntryId: String?      // 父条目（层级世界书）
    var relatedEntryIds: [String]   // 关联的其他条目
    var memoryLinkIds: [String]     // 关联的记忆条目

    // 安全
    var isSpoiler: Bool             // 是否为剧透内容（用户可能不知道）
    var requiresConfirmation: Bool  // 是否需要用户确认才能被角色引用
}

enum WorldBookScope: String, Codable {
    case global     // 全局世界书（所有角色共享）
    case character  // 角色世界书（特定角色专属）
    case session    // 会话世界书（当前会话临时）
}

enum WorldBookEntryType: String, Codable {
    case character, location, timeline, relationship
    case rule, object, organization, style
    case project, canon, nonCanon, userCustom
}

enum CanonLevel: String, Codable {
    case canon       // 正史：绝对权威，不可被对话改变
    case semiCanon   // 半正史：可以作为背景，但在对话中可微调
    case headcanon   // 脑补设定：用户个人理解
    case alternative // AU/if线：平行设定
}
```

## 6.4 世界书触发机制

### 6.4.1 触发流程

```
用户发送消息
    │
    ▼
提取消息中的实体和关键词
    │
    ▼
匹配世界书条目：
  方式 A：关键词精确/模糊匹配（快速，适合短关键词）
  方式 B：向量相似度匹配（适合长描述性触发条件）
  方式 C：混合（关键词初筛 + 向量精排）
    │
    ▼
收集触发条目 → 按 priority 排序 → 应用冷却规则 → 检查 token 预算
    │
    ▼
将触发条目的 content 插入 Context Builder 的 World Context 区
```

### 6.4.2 触发细节

**关键词匹配规则**：
- 精确匹配：消息中出现 `keywords` 中的任一词汇 → 触发
- 别名匹配：消息中出现 `aliases` 中的任一词汇 → 触发（同等效果）
- 大小写不敏感
- 中文分词后匹配

**冷却机制**：
- 同一条目在 cooldownSeconds 内不会重复触发
- 防止角色连续多次机械提及同一设定
- 默认冷却 300 秒（5 分钟）

**优先级排序**：
```
触发条目排序规则：
1. priority 高的优先
2. canonLevel = canon 的优先
3. 首次触发优先于重复触发
4. scope = session（当前会话临时设定）优先于 character 优先于 global
```

### 6.4.3 防污染机制

**原则：不要让角色因为世界书而变得像在背书。**

```
机制：
1. 单次对话最多触发 N 条世界书（默认 5 条）
2. 世界书内容插入 prompt 时标注"背景设定（自然引用，不要直接复述）"
3. System Prompt 包含指令：
   "世界设定是角色的背景知识，不是台词。用自然的方式体现，
    不要机械背诵设定。比如设定说'这个世界有魔法'，
    角色应该在对话中自然提到'上次魔法课'而不是突然说'我们这个世界有魔法。'"
4. 如果条目 requiresConfirmation=true，角色不应主动提及，
   只在用户先提到时才回应
```

## 6.5 设定矛盾处理

### 矛盾检测

```
当用户编辑世界书或导入新设定时：
1. 检查新条目与已有条目的语义冲突
2. 同一 scope 内，同一 entryType 的条目做两两对比
3. 如果相似度 > 0.7 但关键信息矛盾 → 标记为潜在矛盾
```

### 矛盾解决

```
检测到矛盾 → 通知用户：
"你新增的设定 [A] 与已有设定 [B] 可能矛盾：
A：魔法需要法杖才能施展
B：高阶魔法师可以无杖施法
请选择：(1)保留两者，标记为层级关系(2)替换旧设定(3)修改新设定"
```

### Canon Level 优先级

```
矛盾时权威性排序：
canon > semiCanon > headcanon > alternative
高 canonLevel 的设定覆盖低级别的矛盾设定
```

## 6.6 用户临时修改设定

**场景**：用户聊天中说"这个世界其实没有魔法"，但世界书里写了有魔法。

**处理流程**：
```
1. 检测到用户消息与现有世界书设定可能矛盾
2. 角色回复时标记此矛盾（但不直接修改世界书）
3. 后台弹出轻量提示："你刚才说的与设定 [X] 不一致，要更新设定吗？"
4. 用户确认 → 更新世界书条目
5. 用户忽略 → 保持原设定，标记为非正史注释
```

**关键原则**：用户临时口嗨不永久改写世界设定，除非显式确认。

## 6.7 世界书与记忆的连接

**World-linked Memory 机制**：
- 当角色在对话中经历了与世界书条目相关的事件时，生成 World-linked Memory
- 该记忆同时关联世界书条目和对话记忆
- 例如：世界书有条目"霍格沃茨学院系统"，角色被分到格兰芬多后，生成记忆关联此条目

**查询时**：
- Context Builder 检索世界书时，同时拉出关联的 World-linked Memory
- 这样角色既知道"世界的设定"，也知道"自己在这个设定下的经历"

## 6.8 MVP 简化方案

**MVP 阶段**：
- 每个角色一个全局世界书文件（JSON 格式）
- 仅关键词触发（无向量检索）
- 上限 50 条条目
- 无矛盾检测（手动管理）
- 无 canon level 区分
- 世界书编辑器：文本 JSON 编辑或简单表单

**高级版本**：
- 向量检索 + 关键词混合触发
- 分层世界书（全局/角色/会话）
- 自动矛盾检测
- 世界书模板库
- 可视化世界书关系图
- 多人协作世界书
- 从小说/设定文档自动提取世界书条目

## 6.9 开源借鉴

- **SillyTavern Lorebook**：世界书/设定集的行业标准，概念极佳但实现耦合前端。借鉴概念，自研 iOS 原生实现。
- **NovelAI Lorebook**：类似概念。借鉴触发机制设计。
- **LlamaIndex / LangChain 的 RAG**：借鉴检索架构思路，但世界书的触发逻辑比通用 RAG 更复杂（有关键词+语义+冷却+优先级）。
