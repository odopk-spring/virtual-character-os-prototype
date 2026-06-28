# 09 — 主动消息系统设计

## 9.1 核心原则

主动消息是虚拟人物"有自己生活"的关键体现。但它不是营销推送，必须遵循以下原则：

1. **角色驱动**：消息来自角色的生活/记忆/关系，不是系统模板
2. **自然频率**：像真实朋友偶尔发消息，不是定时打卡
3. **内容个性化**：基于记忆和关系生成独特内容，不群发
4. **用户可控**：频率、类型、时段全部可调
5. **不骚扰**：用户低回应期自动降低频率

## 9.2 触发条件体系

### 触发类型

| # | 触发类型 | 说明 | 示例 |
|---|---------|------|------|
| 1 | 时间触发 | 基于角色日程的自然节点 | 早上醒来、晚上睡前、午休 |
| 2 | 记忆触发 | 角色"想起来"之前的事 | "你上次说的那个面试，是今天吗？" |
| 3 | 关系触发 | 关系变化引发的主动 | 很久没联系了，主动问候 |
| 4 | 生活触发 | 角色自己的生活中发生的事 | "今天上课被点名了，好尴尬" |
| 5 | 事件触发 | 用户的重要日期 | 用户说过今天有考试/面试 |
| 6 | 世界书触发 | 世界设定中的事件 | 世界观中有节日/事件发生 |
| 7 | 长期未联系 | 用户很久没打开 App | "好久不见，最近还好吗" |
| 8 | 纪念日触发 | 特殊日期 | 角色被创建一周年 |
| 9 | 情绪修复触发 | 上次互动有矛盾/不愉快 | "上次的事我想了想……" |
| 10 | 共同项目进展 | 与用户的共同项目有更新 | "我们的那个计划，我想到了一个点" |

### 触发条件检查

```swift
func checkProactiveTriggers(
    character: CharacterProfile,
    state: CharacterCurrentState,
    relationship: RelationshipState,
    memories: [MemoryItem],
    now: Date
) -> [ProactiveTrigger] {
    
    var triggers: [ProactiveTrigger] = []
    
    // 1. 时间触发
    if isWakeUpTime(state, now) && !alreadySentToday(.morningGreeting) {
        triggers.append(.morningGreeting)
    }
    
    // 2. 记忆触发（用户的重要事件）
    for memory in memories where memory.type == .episodic {
        if let eventDate = memory.eventDate,
           isToday(eventDate) || isTomorrow(eventDate) {
            triggers.append(.memoryEvent(memory))
        }
    }
    
    // 3. 关系触发（长期未联系）
    let daysSinceLastInteraction = daysSince(relationship.lastInteractionAt)
    if daysSinceLastInteraction > relationship.proactiveThreshold {
        triggers.append(.longTimeNoSee(daysSinceLastInteraction))
    }
    
    // 4. 生活触发（角色的生活中发生了有趣的事）
    if state.activity == .freeTime && randomProbability(0.15) {
        triggers.append(.lifeMoment)
    }
    
    // 5. 情绪修复触发
    if relationship.conflict > 0.3 && daysSinceLastInteraction > 1 {
        triggers.append(.emotionalRepair)
    }
    
    // ... 更多触发检查
    
    return triggers
}
```

## 9.3 频率控制

### 按关系类型的频率上限

| 关系类型 | 每日上限 | 每周上限 | 触发概率 | 说明 |
|---------|---------|---------|---------|------|
| stranger | 0 | 0 | 0 | 陌生人不会主动发消息 |
| acquaintance | 0-1 | 1-2 | 低 | 刚认识，偶尔打招呼 |
| casual_friend | 1-2 | 3-5 | 中 | 像普通朋友 |
| close_friend | 1-3 | 5-10 | 中高 | 熟悉了，会主动分享 |
| collaborator | 1-2 | 3-7 | 中 | 项目相关主动联系 |
| companion | 1-4 | 5-14 | 高 | 亲密，主动分享多 |
| distant | 0-1 | 0-2 | 很低 | 疏远期 |
| conflict | 0-1 | 1-3 | 低 | 矛盾期，偶尔尝试修复 |
| repair | 1-2 | 3-5 | 中 | 修复期，主动示好 |

### 用户回应率自适应

```swift
func adaptiveFrequency(
    baseFrequency: Int,              // 基础频率（每天上限）
    userResponseRate: Double,        // 用户对主动消息的回应率
    userExplicitPreference: Int?     // 用户在设置中调的频率（可选）
) -> Int {
    
    var adjustedFrequency = baseFrequency
    
    // 如果用户几乎不回应主动消息 → 降低频率
    if userResponseRate < 0.2 {
        adjustedFrequency = max(0, adjustedFrequency - 2)
    } else if userResponseRate < 0.4 {
        adjustedFrequency = max(0, adjustedFrequency - 1)
    } else if userResponseRate > 0.8 {
        adjustedFrequency = min(5, adjustedFrequency + 1)  // 用户喜欢互动
    }
    
    // 用户手动设置的优先级最高
    if let pref = userExplicitPreference {
        adjustedFrequency = pref
    }
    
    return adjustedFrequency
}
```

## 9.4 主动消息生成

### 生成流程

```
1. 触发条件命中
2. 调用 Context Builder（特殊模式：proactive）
3. Context Builder 收集：
   - 角色当前状态
   - 触发相关的记忆
   - 关系状态
   - 距离上次互动的时间
   - 用户最近的活跃状态
4. 组装 prompt（简化版，不需要完整 Context Builder）
5. 调用模型生成 1-2 句主动消息
6. 后处理：
   - 去重检查（与最近主动消息对比）
   - 质量检查（不是模板化废话）
   - 写入消息记录
   - 发送通知
```

### 去重机制

```swift
func isDuplicate(
    newMessage: String,
    recentProactiveMessages: [Message],
    threshold: Double = 0.7
) -> Bool {
    for old in recentProactiveMessages.prefix(5) {
        let similarity = cosineSimilarity(newMessage, old.content)
        if similarity > threshold {
            return true  // 太像了，不发
        }
    }
    return false
}
```

### 防止模板化

```
✗ 禁止的模板化表达：
  "嗨，今天过得怎么样？"
  "早上好！今天也要加油哦！"
  "晚安，做个好梦！"

✓ 好的主动消息（有个性、有上下文）：
  "今天高数课教授又点名了，还好我去了…你上次说你大学时也这样？"
  "刚看到一个超好笑的猫视频，想到你之前发的你家的猫"
  "你上次说的那个面试，是明天对吧？紧张不"
```

## 9.5 避免骚扰

### 骚扰检测规则

```swift
func shouldSuppress(
    trigger: ProactiveTrigger,
    recentMessages: [Message],
    userStatus: UserStatus
) -> Bool {
    
    // 用户刚才还在聊天 → 不需要主动消息
    if minutesSinceLastInteraction < 30 { return true }
    
    // 用户最近主动关闭了通知
    if userStatus.notificationsMuted { return true }
    
    // 用户设置了免打扰时段
    if isInQuietHours(userStatus.quietHoursStart, userStatus.quietHoursEnd) {
        return true
    }
    
    // 最近 2 小时内已经发过主动消息
    if recentProactiveCount(since: .hours(2)) >= 1 { return true }
    
    // 用户已经 7 天没打开 App → 降低频率但不完全停止
    if daysSinceLastOpen > 7 && recentProactiveCount(since: .days(3)) >= 1 {
        return true
    }
    
    return false
}
```

## 9.6 主动消息与通知的呈现

```
┌─────────────────────────────────┐
│  📱 通知中心                     │
│                                  │
│  林晓（学习搭档）                │
│  "今天高数课教授又点名了…"       │
│  刚刚                            │
│                                  │
│  ─── 关键设计 ───                │
│  - 看起来像消息，不像推送          │
│  - 标题是角色名，不是 App 名      │
│  - 内容是角色的原话，不是系统文案  │
│  - 没有"点击查看""打开App"        │
└─────────────────────────────────┘
```

## 9.7 纯本地版 vs 云端版

### 纯本地版（MVP）

```
实现：
- UNUserNotificationCenter 本地通知
- 触发：仅时间触发（角色设定的固定时间点）
- 生成：用户打开 App 时生成当日计划、补算离线事件
- 限制：App 不在后台时只能靠用户预设的固定时间通知

用户体验：
"你可以设置角色每天的固定问候时间，比如早上 8 点和晚上 10 点。
 其他主动消息在你打开 App 时触发。"
```

### 云端版（Cloud Life Mode）

```
实现：
- 后端 worker 持续运行角色日程
- 触发检查每分钟执行
- APNs 推送稳定可靠
- 消息在云端生成后推送（需用户授权 API Key 加密上传）

用户体验：
"角色真正拥有自己的生活。TA 会在任何时间主动联系你，
 就像真实朋友一样。"
```

## 9.8 用户设置面板

```
主动消息设置：
├── 总开关：[开/关]
├── 频率滑块：低 ◀───●───▶ 高
├── 免打扰时段：[22:00 - 08:00]
├── 消息类型：
│   ├── ☑ 日常问候（早安/晚安）
│   ├── ☑ 生活分享
│   ├── ☑ 重要事件提醒
│   ├── ☐ 随机闲聊
│   └── ☑ 长期未联系提醒
├── 通知样式：
│   ├── ● 显示消息预览
│   └── ○ 仅显示"{name}发来消息"
└── 重置频率适应（让系统重新学习你的偏好）
```
