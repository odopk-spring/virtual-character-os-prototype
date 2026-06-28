# 17 — MVP 路线图

## MVP 0：技术验证（2-3 周）

### 目标
证明技术可行：BYOK → API → SwiftUI Chat 能跑通。

### 核心功能
- 单个角色硬编码 prompt
- 用户输入 API Key（仅 OpenAI 兼容）
- 基础 SwiftUI 聊天界面
- 流式输出
- 本地消息存储（简单的 Message 表）

### 技术任务
1. 搭建 SwiftUI 项目结构
2. 实现 OpenAI-compatible Provider（URLSession + SSE 流式）
3. 实现 Keychain 存储 API Key
4. 实现基础 Chat UI（消息列表 + 输入框 + 流式显示）
5. 实现 Message 数据模型 + GRDB 存储
6. 实现简单 system prompt 组装

### 数据表
- characters (id, name, system_prompt, created_at)
- messages (id, character_id, role, content, timestamp)

### 不做
- 无角色编辑器（硬编码）
- 无长期记忆
- 无世界书
- 无时间流
- 无主动消息

### 验收标准
- 用户输入 API Key → 选择模型 → 开始聊天
- 流式输出正常显示
- 消息历史保存和加载
- 错误处理（Key 无效、网络错误）

---

## MVP 1：真实角色基础（3-4 周）

### 目标
角色"有基本人格"。用户可以创建和编辑角色。

### 核心功能
- 角色编辑器（文本字段 + 少量滑块）
- 3-5 个预设角色模板
- 角色人格 prompt 动态生成
- 短期记忆（对话上下文管理）
- 简单语义记忆（用户手动添加事实）
- 手动记忆编辑
- 简单世界书（仅关键词触发，≤50 条）
- Context Builder v0（固定 prompt 模板）
- 基础 BYOK Provider 管理（OpenAI + DeepSeek + 自定义）

### 技术任务
1. CharacterProfile 数据模型 + GRDB 表
2. 角色编辑器 UI
3. 角色模板 JSON 文件
4. MemoryItem 数据模型（仅 semantic 类型 + episodic）
5. 记忆手动添加/编辑/删除
6. WorldBookEntry 数据模型 + 简单关键词触发
7. Context Builder 基础实现（固定模板）
8. DeepSeek Provider + Custom Provider
9. API 设置页面

### 数据表
- characters (完整字段)
- messages
- memory_items (semantic + episodic)
- world_book_entries

### 不做
- 无自动记忆抽取
- 无向量检索
- 无复杂触发规则（仅关键词）
- 无时间流

### 验收标准
- 用户创建角色 → 设置人格 → 角色回复符合人格
- 用户手动添加"我叫小张，在北京工作" → 角色后续提及
- 世界书关键词触发：提到"学校" → 角色引用世界书中的学校设定
- 切换不同 Provider 正常工作

---

## MVP 2：长期记忆与世界书（4-6 周）

### 目标
记忆系统可用。角色"记得该记得的"。

### 核心功能
- 自动记忆抽取（基于 LLM，异步）
- 事件记忆（episodic）
- 事实记忆（semantic）自动更新
- 关系记忆（relationship）
- 情绪记忆（emotional）
- 记忆合并与去重
- 记忆矛盾检测
- 记忆评分（confidence/importance）
- 基础遗忘机制（decayScore）
- 世界书触发引擎（优先级 + 冷却）
- Context Builder v1（动态检索 + 优先级排序）
- 反思记忆（手动触发）

### 技术任务
1. MemoryExtractor 抽取引擎实现
2. 抽取 prompt 设计与调优
3. MemoryRanker 排序算法
4. DecayEngine 衰减计算
5. 矛盾检测逻辑
6. 记忆合并逻辑
7. WorldBook TriggerEngine 完善
8. Context Builder 动态组装
9. TokenBudget 实现
10. 记忆管理页面 UI
11. 世界书编辑页面 UI

### 数据表
- memory_items (全部类型)
- memory_contradiction_groups
- world_book_entries (完整字段)

### 不做
- 无主题文档自动生成
- 无反思自动触发
- 无向量检索（仍用关键词）
- 无时间流

### 验收标准
- 对话后自动抽取记忆（用户可以查看）
- 记忆有 confidence/importance 评分
- 角色在相关话题中自然引用记忆
- 矛盾记忆被标记，用户可以处理
- 衰减：不重要且很久未访问的记忆不再被检索

---

## MVP 3：时间流（3-4 周）

### 目标
角色有自己的生活节奏。

### 核心功能
- 角色日程模板（基于人格类型）
- 当前状态解析（基于时间查表）
- 回复延迟策略
- 睡眠/忙碌/空闲三种基本状态
- 打开 App 时补算离线时间流
- 角色状态在 Chat 页面可见
- 不同时间段的回复风格差异

### 技术任务
1. LifeScheduler 实现
2. DailyPlanGenerator 实现
3. StateResolver + 补算逻辑
4. ResponseDelay 策略
5. MoodState 模型 + 演化
6. RealismEngine v1（基础规则）
7. 聊天页状态栏 UI
8. 角色状态页面 UI

### 数据表
- character_schedules
- character_current_states
- mood_history

### 不做
- 无动态日程生成（用固定模板）
- 无主动消息
- 无复杂心情演化
- 离线期间不生成"角色做了什么"的叙事

### 验收标准
- 早上角色回复风格自然不同
- 深夜角色回复简短、显示疲惫
- 角色"上课时"延迟回复
- 用户打开 App 时，角色状态根据当前时间正确显示
- 角色不总是在线/秒回

---

## MVP 4：主动消息本地版（2-3 周）

### 目标
角色可以主动联系用户，但仅限本地通知。

### 核心功能
- 本地通知主动消息（时间触发）
- 用户重要事件提醒（基于记忆）
- 低频主动问候
- 用户可控频率
- 用户可关闭

### 技术任务
1. ProactiveMessaging TriggerChecker
2. ProactiveGenerator（用 LLM 生成消息内容）
3. FrequencyController
4. UNUserNotificationCenter 集成
5. 通知设置页面 UI

### 数据表
- proactive_triggers
- notification_history

### 不做
- 无 APNs（无后端）
- 无生活触发（仅时间触发 + 事件触发）
- 每日主动消息上限 2 条

### 验收标准
- 角色在设定的时间发送本地通知
- 通知内容是角色个性化消息，不是模板
- 用户可以调节频率或关闭
- 用户不回应时自动降低频率

---

## MVP 5：Cloud Life Mode（6-8 周）

### 目标
完整角色生命体验——云端持续运行 + 稳定主动消息 + 跨设备同步。

### 核心功能
- 用户账号系统
- 端到端加密数据同步
- 云端日程 worker
- APNs 稳定主动推送
- 角色日程持续运行（不需要用户打开 App）
- 云端记忆整理（周期性 Reflection）
- 多设备同步

### 技术任务
1. 后端搭建（Vapor / Node.js）
2. 用户认证（Sign in with Apple）
3. E2E 加密实现（CryptoKit）
4. 云端日程 worker
5. APNs 集成
6. 同步协议设计
7. 加密 Key 管理（用户可选上传）

### 风险
- 服务器成本
- 安全合规
- App Store 审核（网络服务需隐私说明）

### 验收标准
- 角色在用户 App 后台时依然能主动推送消息
- 多设备消息/记忆/设定同步
- 加密数据在服务器端不可读
- 用户可以随时撤销云端授权

---

## MVP 6：高级生态（持续迭代）

### 目标
多角色、创作者工具、角色生态。

### 核心功能
- 多角色并行管理
- 多角色关系图（角色之间的互动）
- 世界线可视化
- 创作者模板系统
- 角色包导入/导出
- 角色"试对话"（创作者测试模式）
- iPad 适配
- Widget（桌面查看角色状态）

---

## 各阶段预估时间

| 阶段 | 开发时间 | 累计 | 关键风险 |
|------|---------|------|---------|
| MVP 0 | 2-3 周 | 3 周 | 无 |
| MVP 1 | 3-4 周 | 7 周 | 角色编辑器复杂度 |
| MVP 2 | 4-6 周 | 13 周 | 记忆抽取质量调优 |
| MVP 3 | 3-4 周 | 17 周 | iOS 后台限制 |
| MVP 4 | 2-3 周 | 20 周 | 主动消息避免骚扰 |
| MVP 5 | 6-8 周 | 28 周 | 后端 + 安全合规 |
| MVP 6 | 持续 | - | 复杂度 |

**独立开发者预估**：MVP 2（约 3 个月）即可发布第一个可用版本。
