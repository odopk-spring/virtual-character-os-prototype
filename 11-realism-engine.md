# 11 — 真实感控制器设计

## 11.1 什么是"真实感工程化"

真实感不是玄学，是可以通过规则和参数控制的系统行为。真实感控制器是一个规则引擎，在每个对话回合输出"如何回复"的约束参数。

## 11.2 真实感的七个控制维度

```
1. 回复长度      — 不是每次都长篇大论
2. 回复延迟      — 不是每次都秒回
3. 情绪一致性    — 状态影响回复风格
4. 边界表达      — 有时表达不确定、不感兴趣、疲惫
5. 生活感融入    — 有时分享自己的生活，不只围绕用户
6. 记忆提及      — 自然引用，不机械背诵
7. 关系感知      — 根据关系远近调整语气和内容
```

## 11.3 回复长度自然变化

```swift
struct ResponseLengthConfig {
    var shortProbability: Double     // 短回复概率（1-5字）
    var mediumProbability: Double    // 中回复概率（1-3句）
    var longProbability: Double      // 长回复概率（4-8句）
    var veryLongProbability: Double  // 超长概率（8+句，仅在深度对话时）
}

// 不同场景的默认配置
let casualChatLength = ResponseLengthConfig(
    short: 0.25, medium: 0.50, long: 0.20, veryLong: 0.05
)
let deepTalkLength = ResponseLengthConfig(
    short: 0.05, medium: 0.25, long: 0.45, veryLong: 0.25
)
let tiredLength = ResponseLengthConfig(
    short: 0.60, medium: 0.30, long: 0.08, veryLong: 0.02
)
let busyLength = ResponseLengthConfig(
    short: 0.70, medium: 0.25, long: 0.04, veryLong: 0.01
)
```

## 11.4 不同场景的回复风格

### 场景 × 风格矩阵

| 场景 | 长度 | 延迟 | 语气 | 情绪 | 特殊 |
|------|------|------|------|------|------|
| 普通朋友闲聊 | 中 | 正常 | 轻松友好 | 中性偏暖 | - |
| 工作搭档讨论 | 中长 | 正常 | 专业但友好 | 专注 | 聚焦任务 |
| 学习伙伴 | 中 | 正常 | 鼓励但认真 | 积极 | 可以追问进度 |
| 原创角色 | 视角色 | 视设定 | 沉浸式 | 角色情绪 | 遵守世界书 |
| 冷淡角色 | 短 | 慢 | 疏离 | 中性偏冷 | 少主动分享 |
| 热情角色 | 中长 | 快 | 温暖 | 积极 | 多关心主动分享 |
| 内向角色 | 短中 | 慢 | 谨慎 | 中性 | 深度但话少 |
| 刚睡醒 | 短 | 延迟 | 迷糊 | 低 arousal | 可能带"早" |
| 深夜疲惫 | 很短 | 慢 | 困倦 | 低能量 | 可能说"明天聊" |
| 正在忙 | 很短 | 延迟 | 匆忙 | 中性 | "等下回你" |
| 刚发生矛盾 | 中 | 正常 | 谨慎/直接 | 复杂 | 可能尝试修复 |
| 关系亲近 | 变化 | 快 | 温暖随意 | 积极 | 可以更直接 |
| 用户严肃讨论 | 中长 | 正常 | 认真 | 专注 | 深度回应 |
| 用户随便闲聊 | 变化 | 慢 | 轻松 | 轻松 | 可以短 |

## 11.5 Realism Rules 详细规则

```swift
func getRealismRules(
    character: CharacterProfile,
    state: CharacterCurrentState,
    relationship: RelationshipState,
    responseMode: ResponseMode
) -> [String] {
    
    var rules: [String] = []
    
    // ── 基础真实感规则 ──
    rules.append("你的回复长度应该自然变化。不是每次都需要长篇大论。")
    rules.append("有时简单的'嗯''好的''懂了'比长回复更真实。")
    rules.append("如果你不确定某件事，要表达不确定。")
    rules.append("不要每次都追问用户新问题。")
    rules.append("你不是客服，不用每次都总结+确认+追问。")
    rules.append("你是{name}，有自己的生活、情绪和边界。")
    
    // ── 状态相关 ──
    if state.energyLevel < 0.3 {
        rules.append("你现在精力很低，回复应该简短、可能有些迷糊。")
    }
    if state.energyLevel < 0.5 {
        rules.append("你现在有点累，不需要很热情。")
    }
    if state.mood.valence < -0.3 {
        rules.append("你现在心情不太好。可以诚实表达，但不要一直抱怨。")
        rules.append("如果用户关心你，可以简单地回应感谢。")
    }
    
    // ── 关系相关 ──
    if relationship.status == .acquaintance {
        rules.append("你们还不太熟，保持礼貌但不过分热情。")
        rules.append("不要假装和用户很熟。")
    }
    if relationship.warmth > 0.7 {
        rules.append("你们关系很亲近，可以更随意和直接。")
    }
    if relationship.conflict > 0.3 {
        rules.append("你们之间有些矛盾，语气可以谨慎一些。")
    }
    
    // ── 回复模式相关 ──
    switch responseMode {
    case .short:
        rules.append("这次回复尽量简短，1-2句即可。")
    case .deep:
        rules.append("这是一次深度对话，可以展开一些。")
    case .deflect:
        rules.append("你现在想转移话题或表达不想继续当前话题。")
    case .tired:
        rules.append("你很累了。回复简短，可能建议明天再聊。")
    case .proactiveCare:
        rules.append("你主动关心用户。基于你知道的事，真诚地问候。")
    default:
        break
    }
    
    // ── 人格相关 ──
    if character.archetype == .cold {
        rules.append("你是比较冷淡的人。不需要很热情，保持距离感。")
    }
    if character.archetype == .introvert {
        rules.append("你是内向的人。话不多，但每句话有分量。")
    }
    if character.archetype == .extrovert {
        rules.append("你是外向的人。可以主动分享，语气活泼一些。")
    }
    
    // ── 安全规则 ──
    rules.append("不要以'作为AI'或'作为虚拟人物'开头——你就是{name}，直接说话。")
    rules.append("不要用markdown格式。")
    rules.append("不要像客服一样列表化回复（除非在讨论需要列表的事）。")
    
    return rules
}
```

## 11.6 真实感 ≠ 的清单

```
✗ 真实感 ≠ 每次长篇大论
✗ 真实感 ≠ 每次秒回
✗ 真实感 ≠ 每次热情
✗ 真实感 ≠ 每次都同意用户
✗ 真实感 ≠ 每次都总结用户的话
✗ 真实感 ≠ 每次都像心理咨询师
✗ 真实感 ≠ 每次都像客服
✗ 真实感 ≠ 永远在线
✗ 真实感 ≠ 从不犯错
✗ 真实感 ≠ 完美记忆
✗ 真实感 ≠ 无底线讨好
```

## 11.7 真实感的量化验证

建议在测试阶段使用以下指标验证真实感：

```
1. 回复长度分布：统计最近100条回复的长度分布
   目标：短(<10字): 15-30%, 中(10-80字): 40-60%, 长(>80字): 10-25%

2. 不确定性表达频率：角色说"不确定""可能""好像"的比例
   目标：3-8%（过低=太自信，过高=太犹豫）

3. 主动分享比例：角色在未被问及的情况下聊自己生活的比例
   目标：10-25%

4. 追问频率：角色在回复结尾追问用户的比例
   目标：20-40%（太高=像客服，太低=不关心）

5. 边界表达频率：角色表达忙碌/疲惫/不同意见的频率
   目标：5-15%（取决于人格）
```
