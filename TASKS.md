# TASKS

> 任务队列。每轮只取一个任务执行。完成后停止，等待用户确认。

## Current Milestone

**MVP 0: Technical Chat Loop**

目标：验证最小 BYOK 聊天闭环。

---

## Task Format

每个任务包含以下字段：

* **Status** — pending / in_progress / completed / blocked
* **Goal** — 一句话目标
* **Related Docs** — 需要读取的文档
* **Files Likely To Change** — 预计修改的文件
* **Steps** — 执行步骤
* **Acceptance Criteria** — 验收标准
* **Do Not** — 本轮禁止做的事
* **Review Gate Focus** — 检查重点

---

## Task 0.1: Repository Baseline Check

**Status**: pending

**Goal**: 纯只读检查。输出当前仓库状态报告，不做任何修改。为 Task 0.1b（仓库初始化）提供决策依据。

**Related Docs**:
- PROJECT_RULES.md
- MVP_SCOPE.md
- REVIEW_GATE.md

**Files Likely To Change**:
- **不修改任何文件。** 此任务是只读检查。
- 仅输出报告到 stdout / Dev Report。

**Steps**:
1. 列出当前目录完整结构（`ls -la`）。
2. 判断是否已有 `.xcodeproj` 或 `.xcworkspace`（`find . -name "*.xcodeproj"`）。
3. 判断是否已有 Git 仓库（`git rev-parse --git-dir`）。
4. 判断是否已有 `.gitignore`。
5. 搜索所有文件中是否包含疑似 API Key 字符串（`grep -r "sk-" .` 等模式）。
6. 确认 22 个 PRD 文档完整（`ls 0*.md`）。
7. 确认 8 个短上下文文件哪些存在、哪些缺失。
8. 输出**检查报告**（只读，不做修改）。

**Acceptance Criteria**:
- 输出完整目录结构摘要。
- 明确判断：有无 Xcode 工程、有无 Git、有无 .gitignore。
- 明确判断：有无 API Key 泄露风险。
- 明确判断：哪些短上下文文件存在、哪些缺失。
- **不修改任何文件。**
- **不写任何业务代码。**

**Do Not**:
- ❌ 不执行 `git init`。
- ❌ 不创建 `.gitignore`。
- ❌ 不创建 Xcode 工程。
- ❌ 不创建任何文件。
- ❌ 不修改任何文件。
- ❌ 不实现任何功能。
- ❌ 不引入任何依赖。

**Review Gate Focus**: Scope Gate, Privacy & Security Gate

---

## Task 0.1b: Repository Setup

**Status**: pending

**Goal**: 初始化 Git 仓库、创建 `.gitignore`、确保仓库处于可提交状态。为后续所有任务提供版本控制基础。

**Related Docs**:
- PROJECT_RULES.md
- TASKS.md（本文件）

**Files Likely To Change**:
- `.git/`（新建，git init 产物）
- `.gitignore`（新建）
- 可能需要 `scripts/` 目录占位（可选）

**Steps**:
1. 如果 Task 0.1 报告显示没有 Git 仓库 → 执行 `git init`。
2. 如果 Task 0.1 报告显示没有 `.gitignore` → 创建 `.gitignore`。
3. `.gitignore` 至少包含：
   ```
   .DS_Store
   xcuserdata/
   DerivedData/
   *.xcworkspace/xcuserdata/
   Pods/
   *.xcuserstate
   ```
4. 可选：创建 `scripts/` 目录并放 `.gitkeep`。
5. 执行 `git status` 确认仓库状态干净。

**Acceptance Criteria**:
- `git rev-parse --git-dir` 返回有效路径。
- `.gitignore` 存在且包含 iOS 标准忽略规则。
- `git status` 显示仓库状态（可以有未追踪文件）。
- 不包含任何业务代码。
- 不创建 Xcode 工程。

**Do Not**:
- 不创建 Xcode 工程。
- 不实现任何功能。
- 不引入依赖。
- 不修改 PRD 文档。

**Review Gate Focus**: Scope Gate

---

## Task 0.2: Create iOS Project Skeleton

**Status**: pending

**Goal**: 创建最小 SwiftUI iOS 工程骨架。只搭框架，不写业务代码。

**Related Docs**:
- PROJECT_RULES.md
- MVP_SCOPE.md
- `13-ios-tech-architecture.md`（目录结构参考）

**Files Likely To Change**:
- `VirtualCharacterOS.xcodeproj/`（新建）
- `VirtualCharacterOS/App/VirtualCharacterOSApp.swift`（新建）
- `VirtualCharacterOS/Resources/Assets.xcassets`（新建）
- 目录结构骨架文件夹

**Steps**:
1. 在 Xcode 中创建新 SwiftUI iOS App 项目（或手动创建 Package.swift / xcodeproj）。
2. 设置 Bundle Identifier（建议 `com.example.virtualcharacteros`，后续可改）。
3. 设置最低部署目标 iOS 17.0。
4. 创建基础目录结构（见 Task 0.3 的建议结构）。
5. 确保 App 可以打开（显示默认 ContentView）。
6. 标记 `.gitignore` 覆盖 xcuserdata / DerivedData。

**Acceptance Criteria**:
- Xcode 可打开项目。
- 可在模拟器中启动 App（显示空白或 Hello World）。
- 目录结构骨架就位。
- 不包含任何业务实现。
- 不引入 Swift Package 依赖（除系统自带框架）。

**Do Not**:
- 不实现聊天 UI。
- 不实现 Provider。
- 不实现 Keychain。
- 不实现数据库。
- 不引入 GRDB / SwiftData 等依赖。
- 不写业务逻辑。

**Review Gate Focus**: Scope Gate, Code Gate

---

## Task 0.3: Establish App Directory Structure

**Status**: pending

**Goal**: 在已有工程骨架上建立清晰的目录结构，让后续任务有明确的放置位置。

**Related Docs**:
- PROJECT_RULES.md
- `13-ios-tech-architecture.md`（目录结构参考）

**Files Likely To Change**:
- 新建 `App/` 子目录
- 新建 `Features/Chat/`
- 新建 `Features/Settings/`
- 新建 `Features/Character/`
- 新建 `Core/LLM/`
- 新建 `Core/Security/`
- 新建 `Core/Storage/`
- 新建 `Core/Context/`
- 新建 `Core/Models/`
- 新建 `DesignSystem/`

**Steps**:
1. 创建以下目录结构（在 Xcode 中作为 Group）：
   ```
   VirtualCharacterOS/
   ├── App/
   ├── Features/
   │   ├── Chat/
   │   ├── Settings/
   │   └── Character/
   ├── Core/
   │   ├── LLM/
   │   ├── Security/
   │   ├── Storage/
   │   ├── Context/
   │   └── Models/
   ├── DesignSystem/
   └── Resources/
   ```
2. 每个目录下放一个 `.gitkeep` 或占位注释文件，确保目录被 Git 追踪。
3. 不需要在目录中放实际业务代码。

**Acceptance Criteria**:
- 目录结构在 Xcode 和 Finder 中都可见。
- 每个目录有占位标记。
- 目录结构符合 `13-ios-tech-architecture.md` 的建议（接近即可，不强求完全一致）。
- 不包含业务实现。

**Do Not**:
- 不写业务逻辑。
- 不在目录中放 ViewModel / View 等实现文件。

**Review Gate Focus**: Scope Gate

---

## Task 0.4: Define Core Models v0

**Status**: pending

**Goal**: 定义 MVP 0 需要的最小数据模型。只定义数据，不实现持久化逻辑。

**Related Docs**:
- MVP_SCOPE.md
- `18-data-models.md`（参考，不照搬）

**Files Likely To Change**:
- `Core/Models/ChatMessage.swift`
- `Core/Models/CharacterProfile.swift`
- `Core/Models/ProviderConfig.swift`
- `Core/Models/AppError.swift`

**Steps**:
1. 定义 `ChatMessage`：id, role (user/character/system), content, timestamp。
2. 定义 `CharacterProfile`：id, name, personalityDescription, defaultRelationship。
   - 仅 MVP 0 字段。不做完整人格维度。
3. 定义 `ProviderConfig`：baseURL, modelName。API Key 不在此模型中（用 Keychain 管理）。
4. 定义 `AppError`：enum，包含 networkError, invalidAPIKey, rateLimited, serverError, unknown。
5. 所有模型遵守 Codable（便于 JSON 存储）和 Identifiable。

**Acceptance Criteria**:
- 4 个模型文件编译通过。
- `CharacterProfile` 不默认恋爱关系。
- `ProviderConfig` 不包含 API Key 字段。
- `ChatMessage` 的 role 用 enum 而非自由字符串。
- 不包含 MemoryItem、WorldBookEntry、RelationshipState 等 MVP 1+ 模型。

**Do Not**:
- 不定义完整 MemoryItem。
- 不定义完整 WorldBookEntry。
- 不定义 RelationshipState。
- 不做数据库迁移系统。
- 不实现持久化。

**Review Gate Focus**: Scope Gate, Code Gate

---

## Task 0.5: Implement Keychain Storage v0

**Status**: pending

**Goal**: 实现 API Key 的 Keychain 安全存储。保存、读取、删除三个方法。

**Related Docs**:
- PROJECT_RULES.md
- `12-byok-api-layer.md`（Keychain 部分）

**Files Likely To Change**:
- `Core/Security/KeychainManager.swift`

**Steps**:
1. 实现 `KeychainManager` 类。
2. 方法：`save(key:forProvider:)`、`get(forProvider:)`、`delete(forProvider:)`。
3. 使用 `kSecClassGenericPassword`。
4. 使用 `kSecAttrService` 设置为 Bundle Identifier。
5. 使用 `kSecAttrAccount` 设置为 provider 标识。
6. 实现错误类型 `KeychainError`。
7. 单元测试（如果有条件）。

**Acceptance Criteria**:
- API Key 可以保存到 Keychain。
- API Key 可以从 Keychain 读取。
- API Key 可以从 Keychain 删除。
- API Key 不使用 UserDefaults。
- Keychain 操作不打印 Key 内容到日志。
- 错误时有明确的 Error 抛出。

**Do Not**:
- 不实现 Provider 调用。
- 不实现 UI。
- 不把 Key 写入 UserDefaults。
- 不把 Key 打印到日志。

**Review Gate Focus**: Privacy & Security Gate, Code Gate

---

## Task 0.6: Build Provider Settings UI

**Status**: pending

**Goal**: 用户可以填写 Base URL、Model Name、API Key 并保存配置。

**Related Docs**:
- MVP_SCOPE.md
- `14-ui-ux.md`（API 设置页参考）

**Files Likely To Change**:
- `Features/Settings/ProviderSettingsView.swift`
- `Features/Settings/ProviderSettingsViewModel.swift`

**Steps**:
1. 创建 ProviderSettingsView（SwiftUI Form）。
2. 字段：Base URL（TextField）、Model Name（TextField）、API Key（SecureField）。
3. 保存按钮：API Key → Keychain；Base URL / Model Name → 本地配置（简单的 UserDefaults 或 Plist）。
4. 清除 Key 按钮：删除 Keychain 中的 Key。
5. API Key 字段显示为 `••••••••`（SecureField 默认行为）。
6. 加载时回填已保存的 Base URL 和 Model Name（不从 Keychain 回填 Key 原文，仅显示是否已设置）。

**Acceptance Criteria**:
- Base URL 和 Model Name 可保存和回填。
- API Key 保存到 Keychain，不存 UserDefaults。
- API Key 不在 UI 中完整显示。
- 清除 Key 功能可用。
- 不显示完整 API Key。
- UI 简洁，像 iOS 设置页。

**Do Not**:
- 不实现 Provider 调用。
- 不实现多个 Provider 切换（只做单个 OpenAI-compatible）。
- 不把 Key 写入 UserDefaults。

**Review Gate Focus**: Privacy & Security Gate, Code Gate, Realism Gate（UI 是否简洁不暴露技术细节）

---

## Task 0.7: Define LLM Provider Protocol

**Status**: pending

**Goal**: 定义 OpenAI-compatible Provider 的协议抽象。只定义接口，不做实现。

**Related Docs**:
- `12-byok-api-layer.md`
- MVP_SCOPE.md

**Files Likely To Change**:
- `Core/LLM/LLMProvider.swift`
- `Core/LLM/ChatRequest.swift`
- `Core/LLM/ChatResponse.swift`
- `Core/LLM/ChatMessageDTO.swift`
- `Core/LLM/ProviderError.swift`

**Steps**:
1. 定义 `LLMProvider` protocol：`func chat(request: ChatRequest) async throws -> ChatResponse`。
2. 定义 `ChatRequest`：model, messages, temperature?, maxTokens?。
3. 定义 `ChatResponse`：message (ChatMessageDTO), usage?。
4. 定义 `ChatMessageDTO`：role, content（用于 JSON 编解码）。
5. 定义 `ProviderError`：network, httpError(Int), invalidAPIKey, rateLimited, serverError, decodingError。
6. 给 protocol 加 `sendMessage` 辅助方法签名。

**Acceptance Criteria**:
- Protocol 定义清晰，可以编译。
- ChatRequest / ChatResponse 符合 OpenAI chat completions API 格式。
- 不包含具体 HTTP 实现。
- 不依赖第三方库。

**Do Not**:
- 不实现 HTTP 请求。
- 不实现多 Provider 路由。
- 不实现 tool calling。
- 不实现流式接口（可留 protocol 方法签名，但不实现）。

**Review Gate Focus**: Scope Gate, Code Gate

---

## Task 0.8: Implement OpenAI-compatible Non-streaming Request

**Status**: pending

**Goal**: 实现最小非流式 chat completions HTTP 请求。能调通 API，能拿到回复。

**Related Docs**:
- `12-byok-api-layer.md`
- PROJECT_RULES.md

**Files Likely To Change**:
- `Core/LLM/OpenAICompatibleProvider.swift`
- `Core/LLM/LLMProvider.swift`（可能在 Task 0.7 已建）

**Steps**:
1. 实现 `OpenAICompatibleProvider` 遵守 `LLMProvider` protocol。
2. 使用 URLSession + async/await。
3. 从 Keychain 读取 API Key。
4. 从本地配置读取 Base URL 和 Model Name。
5. 构建 Authorization: Bearer 请求头。
6. 构建 chat completions 请求体（JSON）。
7. 发送 POST 请求。
8. 解析 JSON 响应为 ChatResponse。
9. 错误处理：网络错误、HTTP 非 200、解码错误。
10. **不打印 API Key 到日志**。

**Acceptance Criteria**:
- 用户填写 Base URL + Model Name + API Key 后，可以调用 API。
- 发送"你好"能收到非错误回复。
- 网络错误、401（Key 错）、429（限速）、5xx（服务器错）有处理。
- API Key 不出现日志。
- 非流式（一次性返回完整 response）。

**Do Not**:
- 不实现流式输出（可以留接口，不做实现）。
- 不实现多个 Provider。
- 不实现 tool calling。
- 不实现图片/多模态。

**Review Gate Focus**: Privacy & Security Gate, Code Gate

---

## Task 0.9: Implement Local Message Store v0

**Status**: pending

**Goal**: 实现消息本地持久化。用户关闭 App 重新打开后，之前的消息还在。

**Related Docs**:
- MVP_SCOPE.md
- `13-ios-tech-architecture.md`（存储方案）
- `18-data-models.md`（messages 表参考）

**Files Likely To Change**:
- `Core/Storage/MessageStore.swift`
- `Core/Models/ChatMessage.swift`（可能加字段）

**Steps**:
1. 选择存储方案（SwiftData / GRDB / JSON 文件 / UserDefaults），在报告中说明选择理由。
   - 推荐：SwiftData（零依赖，Apple 原生，MVP 0 够用）或 GRDB（为后续扩展留空间）。
2. 实现 `MessageStore`：save / fetch(for characterId) / deleteAll。
3. 消息按时间排序。
4. App 启动时加载已有消息。
5. 新消息自动保存。

**Acceptance Criteria**:
- 发送消息后，消息被保存。
- 关闭 App 重新打开，消息仍在。
- 按时间正序显示。
- 存储方案选择有明确理由记录在 Dev Report 中。

**Do Not**:
- 不做 MemoryItem 存储。
- 不做 WorldBook 存储。
- 不做复杂数据库架构。
- 不做数据迁移系统。
- 不做云端同步。

**Review Gate Focus**: Scope Gate, Code Gate

---

## Task 0.10: Build Basic Chat View

**Status**: pending

**Goal**: 实现最小聊天页面。用户可以看到消息列表、输入消息、看到角色回复。

**Related Docs**:
- `14-ui-ux.md`（Chat 页面参考）
- REALISM_V0.md
- USER_PERSONA_V0.md

**Files Likely To Change**:
- `Features/Chat/ChatView.swift`
- `Features/Chat/ChatViewModel.swift`
- `Features/Chat/MessageBubble.swift`
- `Features/Chat/MessageInputBar.swift`

**Steps**:
1. 实现 ChatView：消息列表 + 底部输入栏。
2. 消息列表：ForEach 遍历 messages，区分 user（右对齐，蓝色）和 character（左对齐，浅灰）。
3. MessageInputBar：TextField + 发送按钮。
4. ChatViewModel：管理 messages 数组，调用 Provider 发送消息，保存到 MessageStore。
5. Loading 状态：等待 API 回复时显示 loading 指示器。
6. 错误状态：API 失败时显示错误提示（不暴露技术细节给用户）。
7. 自动滚动到最新消息。

**Acceptance Criteria**:
- 用户可以输入文字并发送。
- 用户消息显示在聊天气泡中。
- 角色回复显示在聊天气泡中（如有 API 连接）。
- 有 loading 状态指示。
- 错误时可看到提示。
- 不显示 token 计数、API 调用次数等技术细节在聊天界面。
- UI 简洁，不像调试面板。

**Do Not**:
- 不做角色状态栏（MVP 1）。
- 不做"对方正在输入"。
- 不做消息已读/未读。
- 不做图片/语音。
- 不做 markdown 渲染。

**Review Gate Focus**: Realism Gate, Code Gate

---

## Task 0.11: Implement Character Profile v0

**Status**: pending

**Goal**: 实现固定单角色档案。角色有名字、有人格描述、有默认的关系定位。

**Related Docs**:
- USER_PERSONA_V0.md
- REALISM_V0.md
- `19-examples.md`（角色配置样例）

**Files Likely To Change**:
- `Core/Models/CharacterProfile.swift`（补充或创建）
- `Features/Character/CharacterProfile_v0.swift`（或 JSON 配置文件）

**Steps**:
1. 创建 MVP 0 用的固定角色档案。
2. 角色名：由用户指定（默认可用"林晓"或类似中性名）。
3. 人格描述：简短自然语言。如"25岁设计师，性格开朗但不聒噪，有自己的生活圈子和节奏。"
4. 默认关系：虚拟网友 / 项目搭档。
5. 明确写入：不默认恋爱关系、不默认亲密称呼。
6. 角色档案以 JSON 文件或硬编码方式存在（MVP 0 不做编辑器）。
7. 角色档案被 Context Builder 读取。

**Acceptance Criteria**:
- 角色有名字。
- 角色有人格描述。
- 默认关系是"虚拟网友/项目搭档"，不是"恋人""伴侣"。
- 角色档案中有明确的非恋爱声明。
- 角色档案可以被 Context Builder 读取。
- 不包含"我一直都在""永远陪伴"等禁止表达。

**Do Not**:
- 不做角色编辑器。
- 不做多角色。
- 不做角色模板系统。
- 不做角色头像系统。

**Review Gate Focus**: Realism Gate（重点检查不恋爱化、不假装真人）

---

## Task 0.12: Implement Context Builder v0

**Status**: pending

**Goal**: 组装最小 prompt，让模型知道"自己是谁""在和谁聊天""应该怎么说话"。

**Related Docs**:
- `07-context-builder.md`（概念参考，不照搬）
- USER_PERSONA_V0.md
- REALISM_V0.md
- PROJECT_RULES.md

**Files Likely To Change**:
- `Core/Context/ContextBuilder.swift`
- `Core/Context/PromptAssembler.swift`

**Steps**:
1. 实现 `ContextBuilder`。
2. build() 方法组装以下内容：
   - **角色名 + 人格描述**（来自 Character Profile v0）
   - **当前时间**（来自 Date()）
   - **USER_PERSONA_V0 摘要**（约 150-200 tokens 精简版）
   - **REALISM_V0 核心规则摘要**（约 150-200 tokens 精简版）
   - **最近消息**（最近 N 条，N 由简单 token 估算决定）
3. 组装为 OpenAI messages 格式：[system, user, character, user, character, ...]。
4. System message 包含所有系统指令。
5. token 估算用简单字符数/4 的方式（不引入 tokenizer 库）。

**Acceptance Criteria**:
- System prompt 中包含角色人格、用户画像摘要、真实感规则。
- System prompt 中不包含"你是 AI 助手""你是客服""你永远在线"。
- System prompt 中包含"你不是真人，但你是一个真实感很强的虚拟人物"。
- prompt 长度在合理范围（system ≤ 2000 tokens）。
- 最近消息能被正确追加。

**Do Not**:
- 不接世界书。
- 不接复杂记忆检索。
- 不做 RAG。
- 不做意图识别。
- 不做动态 response mode。
- 不做 token 精确计数（字符估算即可）。

**Review Gate Focus**: Realism Gate（重点检查 prompt 是否恋爱化、是否客服腔）

---

## Task 0.13: End-to-End Chat Loop

**Status**: pending

**Goal**: 串联所有 MVP 0 组件。用户发送消息 → Context Builder 组装 → Provider 调用 API → 模型回复 → 保存 → UI 展示。完成一个完整的对话闭环。

**Related Docs**:
- MVP_SCOPE.md
- REVIEW_GATE.md

**Files Likely To Change**:
- `Features/Chat/ChatViewModel.swift`（串联逻辑）
- 可能调整前面任务的文件做集成适配

**Steps**:
1. 在 ChatViewModel 中串联：
   - 用户输入 → 创建 ChatMessage(role: user)
   - 调用 ContextBuilder.build()
   - 调用 Provider.chat(request)
   - 解析回复 → 创建 ChatMessage(role: character)
   - 保存两条消息到 MessageStore
   - 更新 UI
2. 处理错误路径：Key 无效、网络不通、模型错误。
3. 确保错误信息对用户友好（"好像出了点问题，检查一下 API Key？"而不是"HTTP 401 Unauthorized"）。

**Acceptance Criteria**:
- 至少可以完成一轮真实 API 对话。
- 错误时 UI 可见友好提示。
- 重启后消息仍在。
- 不泄露 API Key。
- 角色回复符合 REALISM_V0.md（不像客服、不恋爱化）。

**Do Not**:
- 不做流式输出。
- 不做多轮记忆。
- 不做主动消息。
- 不做任何 MVP 1+ 功能。

**Review Gate Focus**: All 4 Gates（Scope / Code / Privacy & Security / Realism）

---

## Task 0.14: MVP 0 Smoke Check

**Status**: pending

**Goal**: 执行 MVP 0 验收前的完整 smoke check。逐项对照 MVP_SCOPE.md 的 MVP 0 必须做清单，验证每一条。

**Related Docs**:
- MVP_SCOPE.md
- REVIEW_GATE.md
- PROJECT_RULES.md
- REALISM_V0.md

**Files Likely To Change**:
- 无（只做检查和报告，不改代码，除非发现必须修的 bug）

**Steps**:
1. 对照 MVP_SCOPE.md 的"MVP 0 必须做"清单，逐项检查。
2. 对照"MVP 0 明确不做"清单，确认无越界。
3. 跑一次完整对话。
4. 检查消息持久化（杀进程重开）。
5. Keychain 安全检查（grep UserDefaults / print）。
6. REVIEW_GATE.md 四项 Gate 逐项检查。
7. 记录所有发现。

**Acceptance Criteria**:
- App 可启动。
- 设置可保存。
- 消息可发送。
- 回复可展示。
- 消息可持久化。
- Keychain 检查通过（无 Key 泄露）。
- Scope Gate 通过（无越界）。
- Realism Gate 通过（不像客服、不恋爱化）。

**Do Not**:
- 不新增功能。
- 不修非阻断性 bug（只记录，不进 MVP 0 范围）。

**Review Gate Focus**: All 4 Gates

---

## Task 0.15: MVP 0 Report

**Status**: pending

**Goal**: 输出 MVP 0 完成报告。总结做了什么、没做什么、风险在哪、能不能进 MVP 1。

**Related Docs**:
- MVP_SCOPE.md
- REVIEW_GATE.md
- TASKS.md（本文件）

**Files Likely To Change**:
- 新增 `DEV_REPORT_MVP0.md`（或按 REVIEW_GATE.md 的 Report Add-on 格式）

**Steps**:
1. 列出 MVP 0 所有完成项。
2. 列出 MVP 0 未完成项（如有）。
3. 列出已知风险。
4. 列出是否满足 MVP_SCOPE.md 的全部 MVP 0 要求。
5. 给出是否建议进入 MVP 1 的判断。
6. 给出 MVP 1 调整建议。
7. 按 REVIEW_GATE.md 的 Report Add-on 格式输出。

**Acceptance Criteria**:
- 报告包含完成项 / 未完成项 / 风险 / MVP 1 建议。
- 报告包含 Review Gate Result（4 个 Gate）。
- 报告不包含无证据自评。

**Do Not**:
- 不开始 MVP 1。
- 不新增功能。

**Review Gate Focus**: All 4 Gates

---

## Future Tasks (MVP 1+)

以下任务不在本轮，仅记录供后续参考：

- Task 1.1: Character Editor v1
- Task 1.2: MemoryItem Data Model
- Task 1.3: Manual Memory CRUD
- Task 1.4: Basic WorldBookEntry
- Task 1.5: WorldBook Manual CRUD
- Task 1.6: Context Builder v1
- Task 1.7: Simple Character State
- Task 1.8: Response Delay Simulation
- Task 1.9: MVP 1 Smoke Check & Report

> MVP 2+ 任务见 `17-mvp-roadmap.md`。
