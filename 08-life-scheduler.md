# 08 — 时间流系统设计（核心）

## 8.1 核心概念

角色不是永远在线等待用户。TA 有自己的生活节奏——睡觉、工作、学习、通勤、休息、社交、娱乐、低能量状态。时间流系统管理这一切。

**关键设计原则**：用户打开 App 时，角色"已经在生活"，而不是"刚被唤醒"。

## 8.2 每日计划生成器

### 角色日程模板（人格相关）

```swift
struct DailySchedule: Codable {
    var date: Date
    var characterId: String
    var timeBlocks: [TimeBlock]
    var generatedAt: Date
    var generationMethod: GenerationMethod
}

struct TimeBlock: Codable {
    var startTime: String      // "07:00"
    var endTime: String        // "08:00"
    var activity: ActivityType
    var location: String?      // "家""公司""学校"
    var energyLevel: Double    // 此时间段精力水平 0.0 - 1.0
    var availability: Availability  // 对用户消息的响应能力
    var moodModifier: Double   // 对心情的影响 -0.3 到 +0.3
}

enum ActivityType: String, Codable {
    case sleeping, wakingUp, morningRoutine
    case working, studying, inClass, inMeeting
    case commuting, lunch, break_
    case exercising, hobby, socializing
    case resting, freeTime, eveningRoutine
    case lowEnergy, busy
}

enum Availability: String, Codable {
    case unavailable     // 无法回复（睡眠、重要会议）
    case delayed         // 看到但延迟回复（上课、工作）
    case slow            // 可以回复但慢（通勤、休息）
    case normal          // 正常回复
    case quick           // 有空快速回复
}
```

### 不同人格的日程差异

| 角色类型 | 起床 | 睡觉 | 工作/学习 | 自由时间 | 社交活跃时段 |
|---------|------|------|----------|---------|------------|
| 学生 | 7:00 | 23:30 | 8:00-17:00 | 17:00-22:00 | 晚间 |
| 上班族 | 7:30 | 23:00 | 9:00-18:00 | 18:00-22:00 | 晚间 |
| 自由职业 | 9:00 | 凌晨1:00 | 灵活 | 大部分时间 | 全天不规律 |
| 夜猫子 | 11:00 | 凌晨3:00 | 下午-晚上 | 深夜 | 深夜 |
| 晨型人 | 5:30 | 21:30 | 7:00-15:00 | 15:00-20:00 | 早晨/下午 |
| 内向角色 | 8:00 | 23:00 | 正常 | 独处时间多 | 有限 |
| 外向角色 | 7:00 | 凌晨0:00 | 正常 | 社交多 | 广泛 |

### 日程生成

**MVP 方式**：固定模板。用户在角色编辑器中设置角色的基本作息，系统生成固定周日程。

**高级方式**：LLM 每日生成。每天凌晨（或用户打开 App 时补算），用轻量 prompt 生成当日计划：
```
System: 你是 {name} 的日程生成器。基于角色设定和当前日期，生成今天的计划。
角色设定：{character_profile}
今天是：{date} ({weekday})
最近事件：{recent_events}
请生成今天的 time blocks。
```

## 8.3 当前状态解析器

```swift
struct CharacterCurrentState: Codable {
    var characterId: String
    var timestamp: Date
    var activity: ActivityType
    var location: String?
    var energyLevel: Double       // 0.0(精疲力竭) - 1.0(精力充沛)
    var mood: MoodState
    var availability: Availability
    var currentPlanDescription: String  // "正在图书馆复习高数"
    var lastUserInteraction: Date?
    var unreadMessageCount: Int
    var isSleeping: Bool
    var busyUntil: Date?
}

struct MoodState: Codable {
    var valence: Double           // -1.0 到 1.0
    var arousal: Double           // 0.0(平静) 到 1.0(兴奋)
    var dominantEmotion: String   // "平静""开心""疲惫""焦虑""兴奋"...
    var moodDescription: String   // "今天心情还行，有点困"
    var lastUpdated: Date
}
```

### 状态补算（核心机制）

因为 iOS 不能保证后台运行，需要在 App 打开时补算从上次活跃至今的状态变化：

```swift
func catchUpState(
    character: CharacterProfile,
    lastActive: Date,
    now: Date
) -> CharacterCurrentState {
    let elapsed = now.timeIntervalSince(lastActive)
    
    // 1. 根据日程模板，确定角色在这段时间做了什么
    let elapsedBlocks = schedule.getBlocks(between: lastActive, and: now)
    
    // 2. 计算精力变化
    let energyChange = calculateEnergyChange(blocks: elapsedBlocks)
    
    // 3. 计算心情变化（可能受以下影响）
    //    - 用户是否很久没联系
    //    - 角色今天是否有重要事件
    //    - 天气/季节（可选）
    let moodChange = calculateMoodChange(
        blocks: elapsedBlocks,
        daysSinceLastContact: daysSince(lastUserInteraction)
    )
    
    // 4. 根据当前时间确定角色正在做什么
    let currentBlock = schedule.getBlock(at: now)
    
    return CharacterCurrentState(
        activity: currentBlock.activity,
        energyLevel: clamp(energyChange, 0, 1),
        mood: moodChange,
        availability: currentBlock.availability,
        // ...
    )
}
```

## 8.4 回复延迟策略

### 延迟决策矩阵

```
用户消息到达
    │
    ▼
检查角色当前 availability：
    │
    ├── unavailable ──→ 不回复（等角色醒来/有空时回复）
    │   └── 系统提示："{name}正在睡觉，预计明早回复"
    │
    ├── delayed ──→ 延迟回复（5-60分钟随机延迟）
    │   └── 原因：上课中、开会中、工作中
    │   └── 用户感知：消息显示"已送达"，但角色不立即回
    │
    ├── slow ──→ 慢回复（1-15分钟随机延迟）
    │   └── 原因：通勤中、吃饭中、休息中
    │
    ├── normal ──→ 正常回复（0-5分钟）
    │   └── 有时也会"正在输入..."然后只回几个字
    │
    └── quick ──→ 快速回复（几乎即时的感觉）
        └── 原因：正好在看手机、自由时间
```

### 延迟实现

```swift
func calculateResponseDelay(
    state: CharacterCurrentState,
    relationship: RelationshipState,
    userMessage: Message,
    realismConfig: RealismConfig
) -> TimeInterval {
    
    var baseDelay: TimeInterval
    
    switch state.availability {
    case .unavailable: return .infinity  // 不回复
    case .delayed:    baseDelay = 600 + Double.random(in: 0...1800)  // 10-40分钟
    case .slow:       baseDelay = 60 + Double.random(in: 0...600)    // 1-11分钟
    case .normal:     baseDelay = Double.random(in: 3...180)         // 3秒-3分钟
    case .quick:      baseDelay = Double.random(in: 1...30)          // 1-30秒
    }
    
    // 关系修正：越亲密可能回得越快（但也有例外）
    if relationship.warmth > 0.7 {
        baseDelay *= 0.7
    }
    
    // 用户消息紧急度
    if userMessage.isUrgent {
        baseDelay = min(baseDelay, 30) // 紧急消息快速回
    }
    
    // 角色人格修正
    baseDelay *= character.responseSpeedFactor  // 0.5(快) - 1.5(慢)
    
    // 随机抖动（±30%）
    baseDelay *= Double.random(in: 0.7...1.3)
    
    return baseDelay
}
```

**iOS 实现注意**：
- 如果 App 在前台：用 `Task.sleep` 模拟延迟（角色"正在做别的事"）
- 如果 App 在后台：延迟由本地通知实现（延迟后发通知"角色回复了"）
- 如果用户关闭了通知：下次打开 App 时可以看到角色的延迟回复

## 8.5 角色心情演化

```swift
func updateMood(
    currentMood: MoodState,
    character: CharacterProfile,
    events: [RecentEvent],
    timeSinceLastUpdate: TimeInterval
) -> MoodState {
    
    var newMood = currentMood
    
    // 1. 自然回归（向基线回归）
    let baselineMood = character.emotionalRange.baseline
    newMood.valence += (baselineMood.valence - newMood.valence) * 0.1
    
    // 2. 时间影响
    let hour = Calendar.current.component(.hour, from: Date())
    switch hour {
    case 6...9:   newMood.arousal += 0.1  // 早晨慢慢清醒
    case 14...16: newMood.arousal -= 0.05 // 午后低谷
    case 22...24: newMood.arousal -= 0.1  // 晚上困
    default: break
    }
    
    // 3. 事件影响
    for event in events {
        newMood.valence += event.moodImpact * 0.3
    }
    
    // 4. 用户互动影响
    // 如果用户很久没联系 → 可能有点失落（取决于关系深度）
    // 如果用户最近频繁互动 → 心情通常更好
    
    return newMood.clamped()
}
```

## 8.6 不同场景处理

### 场景举例

**早上刚醒**：
```
时间：7:30
状态：刚醒，还有点迷糊
精力：0.4
心情：中性偏困
回复风格：简短，可能带"早""刚醒"等提示
延迟：略有延迟（在洗漱）
```

**上课/工作时**：
```
时间：10:00
状态：正在上课
精力：0.7
心情：正常
可用性：delayed
回复风格：短，可能说"在上课，等下回你"
延迟：10-40分钟
```

**深夜疲惫**：
```
时间：23:30
状态：准备睡了，很困
精力：0.2
心情：疲惫
回复风格：很简短，可能只有几个字，可能说"明天聊，困了"
```

**很久没联系时**：
```
用户 3 天没发消息→角色状态：
- 心情略微下降
- 如果关系熟悉 → 角色会主动问候（见主动消息系统）
- 下次对话时，角色自然提到"好久没聊了"
```

**用户有重要事件时**：
```
系统检测到用户说过今天有考试 → 角色当天状态：
- 早上主动发消息"今天考试加油"
- 全天对用户消息的回复优先级提高
- 晚上可能问"考得怎么样"
```

**用户连续发很多消息**：
```
角色处理：
- 如果角色正忙 → 可能回复"你发了好多，我还在上课，等下看"
- 如果角色有空 → 逐条回应但可能合并
- 如果用户消息显得焦虑 → 角色可以表达关心但也可能说"你慢慢说，我在"
```

## 8.7 三种部署方案

### 方案 A：纯本地版

```
实现方式：
- 日程：用户设置固定模板 + 角色人格决定默认作息
- 状态：基于当前时间查表
- 补算：App 打开时计算时间差，模拟离线期间的状态变化
- 延迟：App 在前台时用 Timer 模拟
- 主动消息：仅本地通知（见主动消息章）
- 睡眠期间：本地通知暂存消息，用户打开时显示

优点：零服务器成本，强隐私
缺点：App 不打开时角色"暂停"，主动消息不可靠
```

### 方案 B：轻后端版（Cloud Life Mode）

```
实现方式：
- 日程：云端 worker 运行角色日程（轻量 cron job）
- 状态：云端持续追踪
- 补算：不需要（云端一直在运行）
- 延迟：云端触发推送的时机就是"角色回复的时机"
- 主动消息：后端 worker 触发 → APNs 推送
- 数据：端到端加密同步

优点：稳定主动消息，角色"真正在生活"
缺点：需要服务器，需要用户信任
成本：轻量 worker + APNs，约 ¥100-300/月（支持数百用户）
```

### 方案 C：完整云端角色生命系统

```
在方案 B 基础上增加：
- 多角色并行日程
- 角色间互动（两个角色可以"聊天"）
- 世界时间线自动推进
- 全局事件系统

成本：需要更强的服务器，约 ¥500-2000/月
建议：独立开发者先不做，等用户量起来再考虑
```

## 8.8 时间流与 iOS 限制的兼容

### iOS 后台限制的现实

```
- 纯本地 App 无法保证长期后台运行
- BGTaskScheduler 不可靠（系统决定何时执行）
- 主动消息如果依赖后台执行，用户体验会很差
```

### 应对策略

```
1. "打开时补算"是基础方案（本地版必须）
2. 本地通知可用于简单提醒（用户设置的时间点）
3. 如果需要稳定主动消息 → 必须走 APNs → 必须有后端
4. 给用户明确预期：本地版"角色在你打开 App 时才活跃"
5. 云端版"角色真的有自己的生活"
```

### 建议

```
MVP 阶段：纯本地方案（方案 A），让用户接受"打开 App 时角色在生活"
第二阶段：加入轻后端（方案 B），作为订阅功能
长期：完整云端角色生命系统（方案 C），创作者高级版
```
