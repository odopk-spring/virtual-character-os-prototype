# MVP 1 Backlog — Realistic Conversation Behavior

> 日期：2026-06-28 | 状态：规划中 | 来源：MVP 0 真实测试反馈

## 优先级总览

| 优先级 | 模块 | 复杂度 | 依赖 |
|--------|------|--------|------|
| **P0** | A. Reply Style v1 | 低 | ContextBuilder |
| **P0** | B. Typing Pace v1 | 低 | ChatView/ChatViewModel |
| **P0** | C. Pending Question Tracking v1 | 中 | ContextBuilder |
| P1 | D. Character Agency v1 | 中 | ContextBuilder + CharacterProfile |
| P1 | E. Copy Message v1 | 低 | ChatView |
| P2 | F. Custom Avatar v1 | 低 | ChatBubbleView |
| P2 | G. Character Setting Supplements v1 | 中 | CharacterProfile + Settings UI |

**推荐执行顺序**：A → B → C → E → D → F → G

---

## A. Reply Style v1（P0）

### 目标

- 控制角色回复长度，默认短到中等长度（1-4 句）。
- 角色更像在即时聊天，不像在写报告、写邮件、写作文。
- 支持短句 + 自然分段 + 偶尔追问。
- 不同场景允许不同长度：深度讨论可稍长，日常闲聊应短。

### 非目标

- 不做完整真实感引擎。
- 不做复杂长度模型（如字符数精确控制）。
- 不做用户偏好学习。

### 建议任务编号

Task 1.1: Reply Style v1

### 实现方案

修改 ContextBuilder 的 `buildSystemPrompt` 中 `【真实感规则】` 和 `【输出要求】` 段：

```
- 默认回复 1-3 句，像微信聊天，不像邮件。
- 只有对方在深入讨论时才展开到 4-6 句。
- 不要每句话都分点、总结、反问。
- 可以用短句："嗯""好的""懂了""有道理"。
- 可以分段发，但不要一大段。
```

### 复杂度

**低**。纯 prompt 工程，不涉及 Swift 代码变更。

### 风险

- prompt 约束可能被模型忽略（取决于模型遵循能力）。需要实测调优。
- 过强的长度约束可能导致角色在需要深度时也敷衍。

### 验收标准

- 发送"你好"，角色回复 ≤ 3 句。
- 发送深度技术问题，角色可以展开但不超 6 句。
- 不再出现连续 8+ 句的长篇回复。
- BUILD SUCCEEDED。

---

## B. Typing Pace v1（P0）

### 目标

- 模拟真实打字节奏，用户不会感觉角色"秒回一大段"。
- 根据回复长度设置延迟：短回复快，长回复慢。
- 可以做 staged delivery：先显示"对方正在输入..."，再逐段显示。

### 非目标

- 不做真正的流式输出（streaming 是 MVP 2 的事）。
- 不做逐字打字动画。
- 不做复杂网络模拟。

### 建议任务编号

Task 1.2: Typing Pace v1

### 实现方案

**方案：分阶段延迟（staged delay）**

```
1. 收到 API 完整回复后，不立即显示。
2. 如果回复 ≤ 20 字 → 延迟 0.5-1.5 秒后显示。
3. 如果回复 20-80 字 → 延迟 1-3 秒后显示。
4. 如果回复 > 80 字 → 分 2 段显示：
   - 第一段（前 50%）: 延迟 1-2 秒后显示
   - 第二段（后 50%）: 再延迟 1.5-3 秒后显示
5. 延迟期间显示 sending 状态（已有的 ProgressView）。
```

### 复杂度

**低**。在 ChatViewModel 的 `applySuccess` 中加 `Task.sleep` 即可。不需要改 Provider/API 层。

### 风险

- 延迟导致用户感知"慢"而非"真实"。需要让延迟可配置（开关 + 速度滑块，MVP 1 先做开关）。
- 分 2 段显示需要处理 message update 两次，确保 store 同步。

### 验收标准

- 短回复（如"嗯"）大约 1 秒后出现。
- 长回复（100+ 字）分 2 段显示，中间有间隔。
- 延迟开关默认开启，可在设置中关闭。
- 不阻塞 UI（使用 Task.sleep，不用 sync sleep）。
- BUILD SUCCEEDED。

---

## C. Pending Question Tracking v1（P0）

### 目标

- 如果角色在上一轮问了用户一个问题，而用户没有回答，角色在后续对话中能自然再次提起。
- 不做复杂记忆系统，只做轻量"未回答问题"追踪。

### 非目标

- 不做 MemoryItem / 自动记忆抽取。
- 不做多轮跨会话追踪（仅当前会话范围内）。
- 不做复杂 NLP 意图识别。

### 建议任务编号

Task 1.3: Pending Question Tracking v1

### 实现方案

```
1. 在 ContextBuilder 中新增辅助方法：
   extractPendingQuestion(lastAssistantMessage: ChatMessage?) -> String?

2. 规则：
   - 如果最近一条 assistant 消息包含"？"或"吗"或以疑问词结尾
   - 且下一条 user 消息不包含对该问题的回答（简单判断：user 消息 ≤ 5 字可能不是回答）
   - 则在 system prompt 中追加：
     "你上一轮问了用户「{问题摘要}」，用户尚未回答。可以在合适时自然追问。"

3. 如果用户已回答（user 消息 > 5 字且语义相关），清除 pending。
```

### 复杂度

**中**。需要修改 ContextBuilder + 增加简单规则判断（不含 embedding/向量）。

### 风险

- 规则过于简单可能误判：用户 5 字以下可能是简短回答（"去了""没"）。
- 调优方向：可改为检查 user 消息是否包含关键实体而非字数。

### 验收标准

- 角色问"你周末准备干什么？"→ 用户回"嗯" → 下一轮系统提示包含"用户尚未回答…"。
- 角色问"你喜欢什么颜色？"→ 用户回"蓝色" → 不提示。
- 不涉及 MemoryItem 或数据库变更。
- BUILD SUCCEEDED。

---

## D. Character Agency v1（P1）

### 目标

- 角色不完全被动、不完全以用户为中心。
- 角色可以有自己的"当前在做的事"、"轻微情绪"、"偏好"。
- 角色可以主动延续自己之前提过的话题。
- 角色可以拒绝、推迟、表达不确定。

### 非目标

- 不做 Life Scheduler。
- 不做完整 Mood Evolution。
- 不做主动消息系统。
- 不做关系状态机。

### 建议任务编号

Task 1.4: Character Agency v1

### 实现方案

```
1. 在 CharacterProfile 中新增可选字段（MVP 1 手动编辑）：
   - currentStatus: String?  // "最近在准备考研""今天有点累"
   - recentTopics: [String]? // 角色最近主动提过的话题

2. 在 ContextBuilder 的 system prompt 中注入：
   "你当前的状态：{currentStatus}"
   "你最近聊过的话题：{recentTopics}。可以在合适时自然延续。"

3. 在 REALISM_V0 prompt 规则中强化：
   - "你不是被动应答机器。你有自己的事、自己的情绪。"
   - "如果用户要求你做不符合自己状态的事，可以礼貌拒绝或推迟。"
```

### 复杂度

**中**。需要扩展 CharacterProfile 模型 + ContextBuilder + 可能需要 Settings UI 入口。

### 风险

- `currentStatus` 和 `recentTopics` 需要手动维护（MVP 1 不做自动化）。用户可能忘记更新。
- "拒绝/推迟"需要 prompt 调优，确保角色不变得突兀。

### 验收标准

- 设置 currentStatus = "今天有点累" → 角色回复更简短、可能表达疲惫。
- 角色主动提过"周末去了海边" → 后续对话中自然延续（不是每轮都提）。
- 用户可以编辑 currentStatus 和 recentTopics（通过 Settings 或 Character 页面）。
- BUILD SUCCEEDED。

---

## E. Copy Message v1（P1）

### 目标

- 用户可以长按消息气泡复制单条消息内容。

### 非目标

- 不做选区复制（iOS 原生 text selection）。
- 不做整段对话复制。
- 不做分享/转发。

### 建议任务编号

Task 1.5: Copy Message v1

### 实现方案

```
1. 在 ChatBubbleView 的消息气泡上加 .contextMenu：
   ContextMenu {
       Button("复制") {
           UIPasteboard.general.string = message.content
       }
   }

2. 或者使用 .onLongPressGesture 弹出系统复制菜单。
```

### 复杂度

**低**。单文件修改（ChatBubbleView），加 5 行代码。

### 风险

- 无。

### 验收标准

- 长按任意消息气泡 → 弹出"复制"按钮。
- 点击"复制" → 消息内容进入系统剪贴板。
- BUILD SUCCEEDED。

---

## F. Custom Avatar v1（P2）

### 目标

- 用户可以将角色默认头像（蓝色方块 + sparkles 图标）替换为自定义图片。
- 图片本地存储，不上传。

### 非目标

- 不做头像裁剪/滤镜/编辑。
- 不做多角色头像管理。
- 不做云端同步。

### 建议任务编号

Task 1.6: Custom Avatar v1

### 实现方案

```
1. 在 CharacterProfile 中新增 avatarData: Data?（Codable，存本地文件引用或 base64）。
2. 在 Settings 或 Character 页面新增"选择头像"按钮。
3. 使用 PhotosPicker（iOS 16+）选择照片。
4. 图片保存到 Application Support/VirtualCharacterOS/avatars/。
5. ChatBubbleView 和 ChatTopBar 的 AvatarView 支持显示图片。
```

### 复杂度

**中**。需要改 CharacterProfile 模型 + UI（选择器 + 显示）+ 本地文件存储。

### 风险

- PhotosPicker 需要 iOS 16+（当前项目 iOS 17 最低，无问题）。
- 图片文件可能占用存储空间（可设置压缩/尺寸限制）。

### 验收标准

- Settings 页面有"选择头像"入口。
- 选择照片后，ChatView 中角色头像更新为所选图片。
- 重启 App 后头像仍然显示自定义图片。
- 图片仅本地存储，不上传。
- BUILD SUCCEEDED。

---

## G. Character Setting Supplements v1（P2）

### 目标

- 提供更多可选的角色补充设定字段，让用户细化角色行为。
- 不在 MVP 1 全部实现 UI，先做数据模型和 ContextBuilder 接入。

### 非目标

- 不做完整角色编辑器（那是 MVP 1 的 Character Editor 任务）。
- 不做多角色管理。
- 不做所有字段的 UI。

### 建议任务编号

Task 1.7: Character Setting Supplements v1

### 实现方案

```
1. 在 CharacterProfile 中新增可选字段：
   - speakingStyleNotes: String?     // "喜欢用短句""讨厌废话"
   - occupationContext: String?      // "研究生在读"
   - boundaryNotes: String?          // "不喜欢被问体重""不接受深夜闲聊"
   - tabooTopics: [String]?          // "政治""前任"
   - recentLifeEvents: String?       // "昨天刚考完试"

2. ContextBuilder 在 system prompt 中注入这些字段（如非空）。
3. 提供最小手动编辑入口（可以是 Settings 中的多行文本字段，MVP 1 不需要漂亮的编辑器）。
```

### 复杂度

**中**。需要模型扩展 + ContextBuilder 更新 + 最小 UI 入口。

### 风险

- 字段过多可能让 prompt 过长。需要限制每字段长度。
- 用户填入的内容可能包含敏感信息。需要在 UI 提示"这些内容将进入模型 API 请求"。

### 验收标准

- CharacterProfile 新增上述 5 个可选字段。
- 填入内容后，角色在对话中体现对应约束。
- 有最小设置入口（可以是 Settings 中的文本字段）。
- BUILD SUCCEEDED。

---

## MVP 1 推荐执行顺序

```
第 1 轮: Task 1.1  Reply Style v1          (P0, 低复杂度, prompt 工程)
第 2 轮: Task 1.2  Typing Pace v1           (P0, 低复杂度, ChatViewModel)
第 3 轮: Task 1.3  Pending Question v1      (P0, 中复杂度, ContextBuilder)
第 4 轮: Task 1.5  Copy Message v1          (P1, 低复杂度, 快速见效)
第 5 轮: Task 1.4  Character Agency v1      (P1, 中复杂度, 模型扩展)
第 6 轮: Task 1.6  Custom Avatar v1         (P2, 中复杂度)
第 7 轮: Task 1.7  Character Supplements v1 (P2, 中复杂度)
```

**理由**：前三轮（Reply Style + Typing Pace + Pending Question）直接解决用户反馈的核心真实感问题。Copy Message 快速见效（5 行代码）。Character Agency + Avatar + Supplements 需要模型和 UI 变更，放在后面。

## 边界约束（来自 MVP_SCOPE.md）

以下**不在** MVP 1 Backlog 中，仍在推迟范围：

- ❌ 流式输出（streaming）
- ❌ 完整 Memory 系统（MemoryItem 自动抽取/评分/合并/衰减）
- ❌ 完整 WorldBook（触发器引擎/向量检索）
- ❌ Life Scheduler（每日计划生成/离线补算）
- ❌ 主动消息系统
- ❌ 多角色/角色编辑器
- ❌ 关系状态机
- ❌ 云端同步/Cloud Life Mode
- ❌ RAG / embedding / vector search
