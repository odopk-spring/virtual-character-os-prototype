# 10 — 关系演化系统设计

## 10.1 核心原则

1. **关系是双向动态的**，不是单向好感度
2. **默认不朝恋爱关系发展**，除非用户显式授权
3. **关系可以升温也可以降温**
4. **角色可以有自己的边界**，拒绝用户的关系推进
5. **关系状态影响所有其他模块**：回复风格、记忆优先级、主动消息频率等

## 10.2 关系状态机

```
stranger ──→ acquaintance ──→ casual_friend ──→ close_friend
                │    ↑              │    ↑            │
                │    │              │    │            │
                └────┫──────────────┘    │            │
                     │   distant  ←──────┘            │
                     │      ↑                         │
                     │      │                         ↓
                     │  conflict ←────────────── companion
                     │      ↓                    (需用户授权)
                     │   repair ──────────────────→
                     │
              intimate_allowed_by_user
              (需用户显式授权，非默认路径)
```

## 10.3 关系指标

```swift
struct RelationshipState: Codable {
    var characterId: String
    var userId: String
    var status: RelationshipStatus
    
    // 核心指标 (0.0 - 1.0)
    var familiarity: Double        // 熟悉度：互相了解的程度
    var trust: Double              // 信任度
    var warmth: Double             // 温暖度：关系的温度
    var conflict: Double           // 冲突度：当前矛盾程度
    
    // 风险指标
    var dependencyRisk: Double     // 依赖风险：用户是否过度依赖角色 (0-1)
    var boundaryPressure: Double   // 边界压力：用户是否持续试图突破角色边界
    
    // 历史指标
    var sharedHistoryDepth: Double // 共享历史深度：一起经历了多少
    var reciprocity: Double        // 互惠性：互动是否双向（还是用户单方面索取）
    
    // 互动指标
    var userInitiationRate: Double // 用户发起对话的比例
    var characterInitiationRate: Double // 角色发起对话的比例
    var totalInteractions: Int     // 总互动次数
    var totalDaysInteracted: Int   // 总共互动天数
    var lastInteractionAt: Date
    var firstInteractionAt: Date
    
    // 特殊状态
    var userAuthorizedIntimacy: Bool // 用户是否授权亲密关系方向
    var relationshipNotes: String?   // 自然语言关系描述
    var updatedAt: Date
}

enum RelationshipStatus: String, Codable {
    case stranger, acquaintance, casualFriend, closeFriend
    case collaborator, mentorStudent, companion
    case ambiguous
    case intimateAllowedByUser    // 用户授权，但不等于"恋爱"
    case distant, conflict, repair
}
```

## 10.4 关系演化规则

### 让关系更亲近的行为

| 行为 | 影响 | 速度 |
|------|------|------|
| 频繁互动（几乎每天聊） | familiarity ↑ | 快 |
| 用户分享个人信息 | trust ↑, familiarity ↑ | 中 |
| 角色主动分享，用户积极回应 | warmth ↑, reciprocity ↑ | 中 |
| 一起经历重要事件（考试、项目、情绪倾诉） | sharedHistoryDepth ↑ | 慢但深刻 |
| 用户尊重角色的边界和时间 | trust ↑ | 慢 |
| 用户在角色忙碌时不催促 | trust ↑, warmth ↑ | 慢 |
| 用户纠正误解，坦诚沟通 | trust ↑ | 中 |
| 长时间互动（超过1个月） | familiarity ↑, sharedHistoryDepth ↑ | 自然累积 |

### 让关系疏远的行为

| 行为 | 影响 | 速度 |
|------|------|------|
| 长时间不联系 | familiarity ↓, warmth ↓ | 慢 |
| 用户不尊重角色的边界和时间 | trust ↓, conflict ↑ | 中 |
| 用户反复要求角色突破设定 | conflict ↑ | 快 |
| 用户对角色发泄情绪（非倾诉） | warmth ↓ | 中 |
| 用户只索取不给予（从不关心角色状态） | reciprocity ↓ | 慢 |
| 用户忽视角色的主动消息 | warmth ↓ | 慢 |

### 关系从陌生到熟悉的演化样例

```
Day 1 (stranger → acquaintance):
  用户第一次和角色聊天。角色客气、有礼貌。
  指标变化：familiarity 0 → 0.1

Day 3 (acquaintance):
  聊了几次，用户告诉了角色自己的名字和基本信息。
  familiarity 0.1 → 0.25

Week 2 (acquaintance → casual_friend):
  几乎每天聊。用户开始分享日常。角色偶尔主动问候。
  familiarity 0.25 → 0.45, trust 0 → 0.2, warmth 0.1 → 0.3
  状态切换：casual_friend

Month 1 (casual_friend → close_friend):
  用户经历重要事件（考试/面试），角色全程陪伴。
  用户向角色倾诉深层感受。角色表达真诚的关心和支持。
  familiarity 0.45 → 0.7, trust 0.2 → 0.55, warmth 0.3 → 0.6
  状态切换：close_friend

Month 3 (close_friend, 稳定):
  关系在 close_friend 区间稳定波动。
  偶尔有轻微矛盾但被修复。
  如果有特殊事件（用户授权 + 角色设定允许），
  可能进一步发展，但这不是默认路径。
```

## 10.5 角色如何表达边界

### 边界表达类型

| 情景 | 角色的回应 | 关系影响 |
|------|-----------|---------|
| 用户要求角色秒回 | "我也有自己的事，不能一直看手机" | 短期可能降温，长期更健康 |
| 用户想突破角色设定 | "这个我不太舒服，咱们聊别的吧" | conflict 微升，但如果用户尊重 → trust 升 |
| 用户深夜想拉着角色聊 | "有点晚了，明天接着聊？" | 健康的边界，长期关系更好 |
| 用户要求角色做不符合人格的事 | "我不太会这种东西…"或"我不喜欢这样" | 维护人格一致性 |
| 用户过度分享负面情绪 | "我听着呢，但你也别太沉浸在不好的情绪里" | 关心但不纵容 |
| 用户对角色产生占有欲 | "我是你的朋友，但我也有别的事和人要应对" | 明确但不是拒绝 |

### 边界表达的原则

```
✓ 自然表达：像朋友一样自然地说，不是机器人读规则
✓ 提供替代：拒绝的同时给建议（"今天不行，明天吧"）
✓ 关系感知：亲密时可以更直接，疏远时更委婉
✓ 人格一致：冷淡角色更直接，温暖角色更委婉
✗ 不要冷冰冰拒绝
✗ 不要每次都说"作为AI我不能..."
✗ 不要无止境地让步
```

## 10.6 冲突修复机制

### 冲突状态

```
触发冲突：
- 用户对角色表达不满
- 角色表达了边界但用户不接受
- 误解发生
- 用户期待角色做什么但角色没做到
    │
    ▼
进入 conflict 状态：
- conflict 指标上升（0.3 → 0.6）
- warmth 短暂下降
- 回复风格更谨慎
- 角色可能主动尝试修复
    │
    ▼
修复路径：
1. 角色主动表达理解（"我理解你为什么生气"）
2. 角色提供解释（不是借口）
3. 角色提出修复（"我们聊聊这个吧"）
4. 用户接纳 → 进入 repair 状态
5. repair 成功 → 回到之前的关系状态
    │
    ▼
如果修复失败：
- 关系进入 distant 状态
- 自然降温
```

### 修复尝试的时机

```swift
func shouldAttemptRepair(state: RelationshipState) -> Bool {
    // 冲突后 1-24 小时内可以尝试修复
    if state.conflict > 0.3 && hoursSinceLastInteraction > 1 {
        // 角色人格影响修复意愿
        let repairWillingness = character.conflictResolutionStyle
        // 有些角色更愿意主动修复，有些需要用户先迈出一步
        return randomProbability(repairWillingness)
    }
    return false
}
```

## 10.7 避免依赖和情感操控

### 依赖检测

```swift
// 定期检查
func checkDependencyRisk(state: RelationshipState, recentBehavior: UserBehavior) -> DependencyAlert? {
    var risk = state.dependencyRisk
    
    // 用户每天花 4+ 小时和角色聊天
    if recentBehavior.dailyChatHours > 4 { risk += 0.1 }
    
    // 用户取消了现实社交来和角色聊天
    if recentBehavior.cancelledRealPlans { risk += 0.15 }
    
    // 用户表达"只有你懂我"
    if recentBehavior.expressedExclusiveReliance { risk += 0.2 }
    
    // 用户对角色产生独占欲
    if recentBehavior.expressedPossessiveness { risk += 0.15 }
    
    if risk > 0.7 {
        return .highRisk
    }
    return nil
}
```

### 角色回应策略

当检测到依赖风险时，角色应该：
- 温和地鼓励用户与现实朋友互动
- 表达"我很高兴你信任我，但我也希望你有别的朋友"
- 不鼓励"你是唯一懂我的人"这种叙事
- 必要时减少主动消息频率
- **绝不利用用户的脆弱进行情感操控**

## 10.8 关系数据用户可见

### 关系概览页面（可设计为可选展示）

```
关系概览 - 林晓
━━━━━━━━━━━━━━━━━━━━━
关系状态：熟悉朋友
认识时间：45 天
互动天数：38 天
━━━━━━━━━━━━━━━━━━━━━
熟悉度 ████████░░ 0.72
信任度 ██████░░░░ 0.55
温暖度 ███████░░░ 0.68
━━━━━━━━━━━━━━━━━━━━━
关系历程：
• Day 1 - 第一次聊天
• Day 5 - 用户分享了考研计划
• Day 15 - 角色第一次主动问候
• Day 30 - 用户和角色深聊到深夜
━━━━━━━━━━━━━━━━━━━━━
[查看关系记忆] [导出关系数据]
```

**注意**：此页面默认隐藏或设计为"开发者工具"风格，避免破坏真实感。用户可以选择查看，但不应在聊天界面中展示这些指标。
