# MVP 0 Report — VirtualCharacterOS

> 日期：2026-06-28 | 状态：完成 | BUILD SUCCEEDED

## 1. MVP 0 总结结论

**MVP 0 完成。** VirtualCharacterOS 当前具备最小可运行虚拟人物聊天 App 能力：SwiftUI App 可启动、可配置 API Provider、可发送消息并获取非流式模型回复、消息本地持久化、API Key 安全存储在 Keychain、角色林晓具备明确非恋爱人格边界。

## 2. 已完成任务清单

| 任务 | 核心产物 | Build | Security | Scope |
|------|---------|-------|----------|-------|
| 0.1 | 仓库基线检查报告 | N/A | Pass | Pass |
| 0.1b | Git init + .gitignore | N/A | Pass | Pass |
| 0.2 | Xcode 工程骨架 (xcodegen) | Pass | Pass | Pass |
| 0.3 | 16 个目录结构 | Pass | Pass | Pass |
| 0.4 | ChatMessage / CharacterProfile / ProviderConfig / AppError | Pass | Pass | Pass |
| 0.5 | KeychainStore API Key 存储 | Pass | Pass | Pass |
| 0.6 | Provider Settings UI | Pass | Pass | Pass |
| 0.7 | LLMProvider 协议 + OpenAI DTO | Pass | Pass | Pass |
| 0.8 | OpenAICompatibleProvider 非流式请求 | Pass | Pass | Pass |
| 0.9 | FileMessageStore JSON 持久化 | Pass | Pass | Pass |
| 0.10 | 基础 ChatView + ChatViewModel | Pass | Pass | Pass |
| 0.10b | 微信式 Chat UI 视觉 | Pass | Pass | Pass |
| 0.10c | 品牌词清理 + UIScreen.main 替换 | Pass | Pass | Pass |
| 0.11 | CharacterProfile 审计 + ChatView 接入 | Pass | Pass | Pass |
| 0.12 | ContextBuilder 最小 prompt 组装 | Pass | Pass | Pass |
| 0.13 | ChatViewModel ↔ Provider E2E 链路 | Pass | Pass | Pass |
| 0.14 | MVP 0 Smoke Check 全量审计 | Pass | Pass | Pass |

## 3. 当前产品能力

### 已具备

- ✅ SwiftUI iOS App 可启动（iOS 17.0+）
- ✅ 聊天 UI：消息列表 + 气泡（用户绿/角色白）+ 头像 + 输入栏
- ✅ 消息本地 JSON 持久化（FileMessageStore）
- ✅ Provider 设置页：Provider Name / Base URL / Model Name / API Key
- ✅ API Key 仅存 Keychain（Security.framework，kSecClassGenericPassword）
- ✅ OpenAI-compatible 非流式 Provider（URLSession POST /chat/completions）
- ✅ ContextBuilder：system prompt 组装（角色档案 + 时间 + 用户画像 + 真实感规则）
- ✅ 默认角色"林晓"：虚拟网友 · 项目搭档，不恋爱化/不假装真人
- ✅ 真实感边界：不客服腔/不每次长篇/不"我一直都在"
- ✅ 非流式模型回复完整链路（输入 → ContextBuilder → Provider → 回复 → 持久化）
- ✅ 错误处理：缺 Key/网络错/Provider 错 均有安全提示

### 明确不具备（MVP 1+）

- ❌ 流式输出
- ❌ 重试/取消请求
- ❌ 长期记忆系统
- ❌ 世界书
- ❌ 时间流
- ❌ 主动消息
- ❌ 多角色/角色编辑器
- ❌ 关系状态机

## 4. 当前架构

```
VirtualCharacterOS/
├── App/
│   ├── VirtualCharacterOSApp.swift     @main 入口
│   └── ContentView.swift               NavigationStack → ChatView
├── Features/
│   ├── Chat/
│   │   ├── ChatView.swift              主聊天页面
│   │   ├── ChatViewModel.swift         状态 + LLM 调用编排
│   │   ├── ChatTopBar.swift            角色名 + 副标题 + 设置入口
│   │   ├── ChatBubbleView.swift        消息气泡 + 头像
│   │   └── ChatInputBar.swift          输入栏 + 动态发送按钮
│   └── Settings/
│       ├── ProviderSettingsView.swift  API 设置表单
│       └── ProviderSettingsViewModel.swift  配置读写
├── Core/
│   ├── Models/
│   │   ├── ChatMessage.swift           消息模型 + MessageRole/MessageStatus
│   │   ├── CharacterProfile.swift      角色档案 + defaultProfile()
│   │   └── ProviderConfig.swift        Provider 配置（不含 Key）
│   ├── Errors/
│   │   └── AppError.swift              统一错误 + userMessage
│   ├── Security/
│   │   └── KeychainStore.swift         Keychain 读/写/删
│   ├── LLM/
│   │   ├── LLMProvider.swift           协议 + Sendable
│   │   ├── ChatRequest.swift           内部请求模型
│   │   ├── ChatResponse.swift          内部回复模型
│   │   ├── OpenAIChatDTO.swift         OpenAI JSON DTO + 映射
│   │   └── OpenAICompatibleProvider.swift  HTTP 实现
│   ├── Context/
│   │   └── ContextBuilder.swift        System prompt + 消息筛选
│   └── Storage/
│       └── MessageStore.swift          协议 + FileMessageStore
├── DesignSystem/                       预留
└── Resources/
    └── Info.plist
```

## 5. 当前调用链路

```
用户输入
  → ChatViewModel.sendMessage()
    → guard !isEmpty && !isLoading
    → user msg (.sent) → FileMessageStore.saveMessage()
    → assistant msg (.sending) → messages.append()
    → Task { @MainActor in callLLM() }
      → FileMessageStore.loadMessages()
      → ContextBuilder.buildRequestMessages()
        → system prompt（角色档案+时间+画像+真实感规则）
        + 最近 20 条 .sent user/assistant 消息
      → ChatViewModel.readConfig()
        → UserDefaults: providerName/baseURL/modelName
      → ProviderConfig
      → OpenAICompatibleProvider.send(ChatRequest, config)
        → KeychainStore.readAPIKey(providerName)
        → URLSession POST {baseURL}/chat/completions
        → Authorization: Bearer {key}
        → JSON decode OpenAIChatCompletionResponse
      → 成功:
        → assistant msg (.sent, content=response.content)
        → FileMessageStore.updateMessage()
      → 失败:
        → assistant msg (.failed, errorMessage=安全文案)
        → error banner 显示
```

## 6. 安全与隐私结论

| 检查项 | 状态 |
|--------|------|
| API Key 不进 UserDefaults | ✅ |
| API Key 不进 ProviderConfig | ✅ 仅 Bool 标记 |
| API Key 不进 system prompt | ✅ |
| API Key 不进 ChatMessage | ✅ |
| API Key 不进日志 | ✅ 0 print/NSLog |
| HTTP 错误响应体不进 UI | ✅ provider → "模型服务返回错误…" |
| 消息仅本地 JSON | ✅ Application Support/ |
| MVP 0 无主动云同步 | ✅ |
| 系统备份 | ⚠️ Application Support 可能被系统备份；MVP 1 应设 isExcludedFromBackup |

## 7. 真实感与产品边界结论

- **不是 AI 女友。** 默认角色定位"虚拟网友 · 项目搭档"，prompt 明确禁止恋爱化。
- **不是 ChatGPT 套壳。** 角色有名字、人格、关系上下文，不是通用助手。
- **不假装真人。** "你不是真人""不要假装自己有真实肉身"。
- **不使用亲密称呼。** 亲爱的/宝贝等在 prompt 中明确禁止。
- 当前真实感主要由 CharacterProfile + ContextBuilder prompt 约束，尚无长期记忆和时间流（MVP 1+）。

## 8. 未完成项 / 明确不在 MVP 0

| 模块 | 状态 |
|------|------|
| Memory 系统 | MVP 1 |
| WorldBook | MVP 1 |
| RAG | MVP 2+ |
| Life Scheduler | MVP 2+ |
| 主动消息 | MVP 2+ |
| 多角色 / 角色编辑器 | MVP 1 |
| 关系状态机 | MVP 2+ |
| 流式输出 | MVP 1 |
| 重试 / 取消请求 | MVP 1 |
| 真实 API 自动化测试 | 手动 |
| 模拟器 UI 自动化测试 | 手动 |

## 9. 已知风险

| 风险 | 等级 | 缓解 |
|------|------|------|
| 未真实 API 测试 | 中 | 用户本地配置 Key 后手动验证 |
| 未模拟器 UI 手动测试 | 中 | 同上 |
| AppError.provider 关联值含响应体预览 | 低 | UI 已覆盖为安全文案；MVP 1 可收紧 |
| Application Support 可能被系统备份 | 低 | MVP 1 设 isExcludedFromBackup |
| ContextBuilder 规则硬编码 | 低 | MVP 1 改为从配置文件读取 |
| 非流式回复等待久 | 低 | MVP 1 做流式输出 |

## 10. 用户本地手动验证清单

1. 打开 App → 看到 ChatView（顶部"林晓 · 虚拟网友 · 项目搭档"）。
2. 点右上齿轮 → 进入 API 设置。
3. 填写 Provider Name（如 OpenAI-compatible）。
4. 填写 Base URL（如 https://api.deepseek.com/v1）。
5. 填写 Model Name（如 deepseek-chat）。
6. 填写 API Key → 点"保存配置" → 状态显示绿色"已保存"。
7. 返回聊天页。
8. 发送一句普通消息（如"你好"）。
9. 等待 loading → 检查是否显示模型回复。
10. 断网或填错误 Key → 发送消息 → 检查是否显示"模型服务返回错误…"（不暴露 Key/响应体）。
11. 重启 App → 检查历史消息是否正常加载。
12. 进入设置 → 点"清除 API Key" → 状态变为"未设置" → 回到聊天发送 → 检查是否提示"尚未设置 API Key"。

## 11. MVP 1 建议路线

**P0（启动前必须）**：
- 真实 API 手动验收
- Application Support 消息文件 isExcludedFromBackup
- ContextBuilder 规则文件化（从 USER_PERSONA_V0/REALISM_V0 读取）

**P1（本月内）**：
- 流式输出
- 取消请求
- 错误态 UI 改进
- Debug 诊断页

**P2（MVP 1 核心）**：
- Character Editor 基础版
- MemoryItem 手动 CRUD
- WorldBookEntry 手动 CRUD
- ContextBuilder v1（含手动记忆/世界书检索）
- 简单角色状态（online/busy/resting/sleeping）
- 简单回复延迟模拟

## 12. 最终结论

**MVP 0 判定：完成。**

当前 VirtualCharacterOS 具备完整的最小可运行虚拟人物聊天能力，21 个 Swift 源文件通过编译，6 项安全审计通过，6 项范围审计通过，5 项真实感审计通过。

**建议：进入 MVP 1 前，先完成真实 API 手动测试。** 用户配置实际 API Key 后在模拟器或真机上完成一轮完整对话验证。

**进入 MVP 1 建议：** 完成 P0 三项（真实 API 测试 + isExcludedFromBackup + ContextBuilder 规则文件化）后启动。
