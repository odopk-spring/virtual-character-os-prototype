# REVIEW_GATE

> 每轮任务完成后的检查门。目标是让用户只做判断和评价，不需要亲自审查代码。

## Purpose

这个文件是每轮任务结束前的**硬性检查清单**。执行者（AI 或人类开发者）必须在每轮报告前逐项检查并给出证据。用户只需要审查检查结果，不需要亲自翻代码、跑测试、读日志。

**核心原则**：
- 不通过就不继续
- 没证据就不说通过
- 越界就回滚
- 体验不真实就调整

## Required Before Every Report

每轮报告前，执行者必须逐项回答以下 18 个问题。每一项必须给出明确答案和证据。不能跳过。

1. **当前任务编号是什么？**（从 TASKS.md 获取）
2. **是否只做了当前任务？**（没有顺手重构、没有提前做后续任务）
3. **是否修改了无关文件？**（列出所有修改的文件，标注是否全部在当前任务范围内）
4. **是否引入新依赖？**（SPM / CocoaPods / 手动导入）
5. **是否触碰 MVP 范围外功能？**（对照 MVP_SCOPE.md 检查）
6. **是否读取了必要文件？**（列出本轮实际读取的文件）
7. **是否遵守 PROJECT_RULES.md？**（如该文件存在）
8. **是否遵守 MVP_SCOPE.md？**（如该文件存在）
9. **是否遵守 REALISM_V0.md？**（如果本轮涉及聊天体验/prompt/角色回复）
10. **是否遵守 USER_PERSONA_V0.md？**（如果本轮涉及 Context Builder/角色行为）
11. **是否有 API Key 泄露风险？**（代码中是否有硬编码 Key？日志中是否打印 Key？）
12. **是否把 API Key 写入 UserDefaults？**（必须使用 Keychain）
13. **是否把敏感信息写入日志？**（print/NSLog/os_log 中是否有 Key/Token/隐私数据）
14. **是否运行 build/test/check？**（具体命令 + 具体结果）
15. **如果没运行，是否明确说明原因？**（不能含糊说"没环境"）
16. **是否有"理论上可行""应该能运行"这种无证据自评？**（禁止）
17. **是否更新了 Dev Report？**（如 DEV_REPORT_TEMPLATE.md 存在）
18. **是否停止等待用户确认？**（本轮完成后必须等待，不能自动进入下一个任务）

## Evidence Rules

### 禁止的表达

以下表达在检查报告中**绝对不能出现**。出现即视为该检查项未通过：

- "应该没问题"
- "理论上可行"
- "应该能运行"
- "看起来正确"
- "我已确保"（但没有附带证据）
- "经过审查"（但没有说明审查了什么）
- "符合要求"（但没有说明符合哪条要求）
- "基本完成"（但没有说明完成到什么程度）

### 证据格式要求

每条通过的检查项必须附带以下至少一种证据：

- **编译**：`xcodebuild` 命令 + 输出摘要（成功或具体错误）
- **测试**：测试命令 + 测试结果（通过/失败数量）
- **检查**：grep/find 命令 + 输出（如 `grep -r "UserDefaults" --include="*.swift" .`）
- **对比**：diff 输出或文件变更列表
- **手动验证**：明确描述做了什么操作、看到了什么结果（仅在无法自动化时）

### 未运行的处理

- 如果某项检查无法运行（如没有 Xcode、没有模拟器、没有 API Key），必须写明：
  - 什么检查
  - 为什么无法运行
  - 替代验证方式（如：代码已写但未编译，已由人工 review 语法）
- "没有环境"不是跳过检查的充分理由——至少要做静态检查（grep 模式匹配等）
- 未运行的检查列为 **Checks Not Run**，并在 **User Decision Needed** 中标记

## Scope Gate

检查本轮是否越界。对照 MVP_SCOPE.md 的当前阶段定义。

### MVP 0 禁止实现

- ❌ 复杂记忆系统（MemoryItem 的自动抽取、评分、合并、矛盾检测）
- ❌ 世界书 RAG（WorldBookEntry + TriggerEngine）
- ❌ 主动消息系统（ProactiveMessaging）
- ❌ 后端 / Cloud Life Mode
- ❌ 多角色管理（超过 1 个角色）
- ❌ 云同步 / 多设备
- ❌ 角色市场 / 模板商店
- ❌ 复杂情绪模型（MoodState 演化）
- ❌ 关系自动演化

### MVP 1 允许新增

- ✅ 基础 MemoryItem（手动添加/编辑/删除，仅 semantic + episodic 类型）
- ✅ 基础 WorldBookEntry（手动编辑，仅关键词触发，≤50条）
- ✅ 角色编辑器
- ✅ 预设角色模板
- ✅ Context Builder v0（固定模板）
- ✅ 多个 BYOK Provider（OpenAI + DeepSeek + 自定义）

### MVP 2+ 功能

- 只能保留接口定义（Protocol）或 `// TODO: MVP 2` 注释
- 不能提前实现任何逻辑
- 数据表可以预留字段但不应有完整的 CRUD

### 越界处理

如果检查发现越界：
1. 列出越界的文件/代码
2. 说明属于哪个阶段的哪个功能
3. **回滚越界部分**
4. 不回滚就不通过

## Code Gate

### 编译检查

- [ ] `xcodebuild` 或 Swift Package Manager build 通过？
- [ ] 命令：`______`
- [ ] 结果：`______`

### 代码质量检查

- [ ] 是否有明显的类型错误？（不需要编译就能看出来的）
- [ ] 是否有死代码（定义了但从未使用）？
- [ ] 是否有硬编码 API Key？
  - 检查命令：`grep -r "sk-" --include="*.swift" .`
  - 检查命令：`grep -r "apiKey\|api_key\|API_KEY" --include="*.swift" . | grep -v "Keychain\|keychain\|processInfo\|Info.plist"`
- [ ] 是否有过大的 View？（单文件 >300 行 SwiftUI View）
- [ ] 是否有业务逻辑塞进 View？（View 中直接调用 API、操作数据库）
  - 检查命令：检查 `*View.swift` 是否 import GRDB / 直接 URLSession
- [ ] 是否有重复模型定义？（同一概念在多个文件中定义了不同的 struct）
- [ ] 是否有不必要的依赖？
- [ ] 是否有错误处理？（网络调用、数据库操作是否有 try/catch 或 Result）
- [ ] 是否有最小可测试路径？（至少有一个可以手动验证的流程）
- [ ] 是否遵守目录结构？（对照 PROJECT_RULES.md 或 13-ios-tech-architecture.md 的目录结构）

### 文件变更检查

- [ ] 列出本轮所有修改的文件
- [ ] 每个文件是否在当前任务范围内？
- [ ] 是否有"顺手改"的文件？

## Privacy & Security Gate

### API Key 安全

- [ ] API Key 是否只存 Keychain？
  - 检查命令：`grep -r "UserDefaults.*key\|UserDefaults.*api" --include="*.swift" .`
  - 期望结果：无匹配或匹配的是非 Key 的配置项
- [ ] 是否避免日志打印 API Key？
  - 检查命令：`grep -r "print.*key\|NSLog.*key\|os_log.*key\|debugPrint.*key" --include="*.swift" .`
  - 期望结果：无匹配（或仅有非 Key 的日志）
- [ ] 是否避免把 Key 传给非必要服务？
  - Key 只能出现在：Keychain 读写 + 构建 API 请求的 Authorization Header
  - 不能出现在：统计 SDK、分析 SDK、崩溃报告、任何第三方服务

### 数据隐私

- [ ] 是否明确区分 Local BYOK Mode 和 Cloud Life Mode？
- [ ] 是否有删除数据的未来设计空间？（数据导出 + 数据删除功能至少预留接口）
- [ ] 是否避免默认保存敏感信息？
- [ ] 是否避免未经确认上传用户数据？

### Keychain 实现检查

- [ ] 是否使用了 `kSecClassGenericPassword` 和正确的 service/account？
- [ ] 是否在 App 删除时 Keychain 数据会被清除？（iOS 默认行为：App 删除 → Keychain 清除，除非使用 Keychain Sharing）
- [ ] Keychain access group 是否正确？（如不需要跨 App 共享，不要设置 access group）

## Realism Gate

检查本轮是否遵守 REALISM_V0.md。**如果本轮不涉及聊天体验/prompt/角色行为，此项可以标 N/A，但必须说明原因。**

### 体验方向检查

- [ ] 是否默认 AI 女友？（产品定位）
- [ ] 是否默认恋爱关系？（关系设计）
- [ ] 是否假装真人？（表达方式）
- [ ] 是否像客服？（回复风格）
- [ ] 是否每次都长篇大论？（回复长度）
- [ ] 是否过度热情？（语气）
- [ ] 是否无条件讨好？（边界）
- [ ] 是否没有边界？（角色设定）
- [ ] 是否没证据就说"我记得"？（记忆引用）
- [ ] 是否忽略用户画像？（USER_PERSONA_V0.md）
- [ ] 是否忽略角色状态？（时间/状态感）
- [ ] 是否忽略时间感？
- [ ] 是否把主动消息写成运营推送？
- [ ] 是否暴露系统规则？

### Prompt 检查（如果本轮涉及 prompt 设计）

- [ ] System Prompt 中是否包含 REALISM_V0 的关键规则（精简版）？
- [ ] System Prompt 中是否有"作为 AI/虚拟人物"等禁止表达？
- [ ] System Prompt 中是否避免默认恋爱关系？
- [ ] System Prompt 中是否避免"我一直都在"类表达？
- [ ] 角色回复示例是否符合真实感要求？

### UI 检查（如果本轮涉及 UI）

- [ ] Chat UI 是否看起来像聊天界面而不是调试面板？
- [ ] 不要显示 token 计数、记忆检索数量等内部指标在聊天界面
- [ ] 不要默认粉色/爱心/恋爱暗示主题

## User Review Format

用户后续只需要用以下格式反馈。不需要解释产品、不需要贴 PRD、不需要检查代码。

### 格式 1：通过

> 通过，继续下一个任务。

### 格式 2：不通过 — 证据不足

> 不通过，原因：你没有实际运行 build/test/check。请只补证据或修复检查，不要做新功能。

### 格式 3：不通过 — 范围越界

> 不通过，原因：你提前实现了 MVP 范围外功能 [具体功能]。请回滚越界部分，只保留当前任务。

### 格式 4：不通过 — 体验不真实

> 不通过，原因：回复像客服 / 太恋爱化 / 太长 / 没有边界 / 没有时间感。请只根据 REALISM_V0.md 调整 [具体问题]。

### 格式 5：不通过 — 安全问题

> 不通过，原因：API Key / 隐私 / 日志 / 存储方式存在问题。请只修复安全问题 [具体问题]。

### 格式 6：需要解释

> 我看不懂你改了什么。请用非技术语言解释本轮改动，不要继续写代码。

## Required Report Add-on

每轮 DEV_REPORT_TEMPLATE.md（如果使用了 Dev Report 模板）后必须追加以下内容。

如果不存在 DEV_REPORT_TEMPLATE.md，则直接在任务报告末尾追加。

~~~~md
## Review Gate Result

### Scope Gate
Pass/Fail: 
Evidence: 

### Code Gate
Pass/Fail: 
Evidence: 

### Privacy & Security Gate
Pass/Fail: 
Evidence: 

### Realism Gate
Pass/Fail: (or N/A with reason)
Evidence: 

### Checks Actually Run
Commands:
Results:

### Checks Not Run
Items:
Reasons:

### User Decision Needed
- [ ] pass / fail / experience review / security review
~~~~

## Long Context Control

### 后续每轮默认读取的文件（短上下文集）

后续每轮默认**只读取**以下文件。不要每轮重新读取全部 22 个 PRD 文档。

1. `PROJECT_RULES.md`（如存在）
2. `MVP_SCOPE.md`（如存在）
3. `TASKS.md`（如存在）
4. `LOOP.md`（如存在）
5. `ACCEPTANCE_CRITERIA.md`（如存在）
6. `USER_PERSONA_V0.md`
7. `REALISM_V0.md`
8. `REVIEW_GATE.md`

### 原始 PRD 文档的读取规则

- 原始 22 个 PRD 文档（`01-*.md` 到 `21-*.md`）**只在当前任务明确需要时读取**
- 例如：正在设计记忆系统 → 读取 `05-memory-system.md` 和 `18-data-models.md`
- 例如：正在做 UI → 读取 `14-ui-ux.md`
- 不要一次性读取全部 22 个

### 执行优先级

```
TASKS.md 当前任务
  > MVP_SCOPE.md（范围约束）
    > PROJECT_RULES.md（项目规则）
      > ACCEPTANCE_CRITERIA.md（验收标准）
        > USER_PERSONA_V0.md（用户画像）
          > REALISM_V0.md（真实感规则）
            > 原始 PRD 文档（仅按需读取）
```

### 冲突处理

- 如果原始 PRD 和 MVP_SCOPE.md 冲突 → **以 MVP_SCOPE.md 为准**
- 如果 MVP_SCOPE.md 和 REALISM_V0.md 冲突 → **以 REALISM_V0.md 为准**（真实感优先于范围）
- 如果 USER_PERSONA_V0.md 中的信息和用户在对话中说的不一致 → **以用户最新说法为准**

## Human Work Minimization

### 用户负责

1. 判断是否通过（基于 Review Gate 结果）
2. 判断体验是否真实（特别关注 Realism Gate）
3. 判断方向是否偏离（特别关注 Scope Gate）
4. 判断是否继续下一个任务
5. 提供必要 API Key（但不能写入仓库）
6. 提供少量角色体验反馈（"太热情了""太像客服了""这个回复不错"）

### 用户不负责

1. 重新解释产品（已有 USER_PERSONA_V0.md + PRD）
2. 每轮重新贴长 PRD（短上下文集已覆盖）
3. 亲自拆任务（TASKS.md 和 LOOP.md 已覆盖）
4. 亲自检查所有代码（Code Gate 已覆盖）
5. 亲自判断所有技术细节（Gate 检查清单已覆盖）
6. 手动搬运长上下文（长上下文控制规则已覆盖）
7. 替 AI 编写 Dev Report（REVIEW_GATE 的 Report Add-on 已覆盖）

---

## CODE_REVIEW_APPENDIX_V0

> 所有代码相关任务完成实现后，必须先自行执行本附录审查，再输出 Dev Report。
> 非代码类纯报告任务可跳过，但仍需执行 Scope / Privacy / Realism Gate。

### 适用范围

所有代码相关任务：
- Swift 源码修改
- Xcode 工程配置修改
- 数据模型修改
- Provider / Context / Storage / Security 修改
- UI / ViewModel 修改
- 错误处理修改
- 持久化逻辑修改
- 新增或删除 Swift 文件

### 执行要求

完成实现后 → 先执行本附录 10 项审查 → 再输出 Dev Report。不要只报告 build 成功。

---

### 1. Scope Review

检查本轮是否严格只完成当前 Task。

必须明确列出：
- 本轮实现了什么
- 本轮没有实现什么
- 是否误做了下一阶段功能
- 是否修改了不该修改的文件
- 是否修改原 PRD 文档
- 是否引入新依赖

**如果发现越界，必须回滚越界修改。**

### 2. Architecture Review

检查代码是否符合当前架构分层：

| 层 | 允许 | 禁止 |
|----|------|------|
| UI (Features/*/View) | 展示 + 用户交互 | 直接调 URLSession / Keychain |
| ViewModel | 状态 + 调用链编排 + 错误展示 | 直接调 URLSession |
| Core/LLM | Provider 抽象 + HTTP | 依赖 SwiftUI |
| Core/Context | 上下文组装 | 读 UserDefaults / Keychain / 网络 |
| Core/Security | Keychain 读写 | 依赖 SwiftUI |
| Core/Storage | 本地消息读写 | 保存 API Key / ProviderConfig |
| Core/Models | 领域模型 | 业务逻辑 |

**如果跨层依赖，必须说明原因；非必要必须修正。**

### 3. Privacy & Security Review

| # | 检查项 | 验证命令 |
|---|--------|---------|
| 1 | API Key 不进 UserDefaults | `grep -RIn "UserDefaults.*key\|AppStorage.*key" --include="*.swift" .` |
| 2 | API Key 不进 ProviderConfig | 结构体审计 |
| 3 | API Key 不进 ChatMessage | 结构体审计 |
| 4 | API Key 不进 system prompt | grep ContextBuilder |
| 5 | API Key 不进日志/print/debugDescription/错误文案 | `grep -RIn "print\|NSLog\|os_log" --include="*.swift" .` |
| 6 | Base URL/Model Name 不进 prompt，除非任务明确要求 | grep ContextBuilder |
| 7 | HTTP 原始错误响应体不直接展示给用户 | ChatViewModel audit |
| 8 | HTTP 原始错误响应体不写入 ChatMessage | ChatViewModel audit |
| 9 | prompt/请求体/响应体不完整打印到日志 | grep |
| 10 | Secret scan 0 匹配 | `grep -RInE "sk-[A-Za-z0-9_-]{20,}" .` |

**发现泄露风险必须修复后重新 build + secret scan。**

### 4. Error Handling Review

- 缺 Provider 配置时有安全提示 ✅/❌
- 缺 API Key 时有安全提示 ✅/❌
- 网络失败时有安全提示 ✅/❌
- 解码失败时有安全提示 ✅/❌
- Provider HTTP 错误时只显示简短安全文案 ✅/❌
- 不吞错误导致 UI 卡死 ✅/❌
- 失败后 loading 状态必须恢复 ✅/❌
- 失败消息不得永久停留在 sending 状态 ✅/❌
- 不得因为单条消息失败破坏历史消息加载 ✅/❌

### 5. State & Concurrency Review

- UI 状态更新在 MainActor 上 ✅/❌
- async 调用前后 loading 状态一致 ✅/❌
- 防止重复发送或重复触发 ✅/❌
- 不制造明显 retain cycle ✅/❌
- 不在后台线程直接修改 Published 状态 ✅/❌
- 不让失败路径遗漏状态恢复 ✅/❌
- 严格并发警告必须处理 ✅/❌
- 不得使用 unchecked Sendable 糊弄并发问题，除非报告必要原因和风险 ✅/❌

### 6. Persistence Review

- MessageStore 不保存 API Key ✅/❌
- MessageStore 不保存 ProviderConfig ✅/❌
- MessageStore 不保存 prompt 全文，除非任务明确要求 ✅/❌
- save/update 不制造重复消息 ✅/❌
- load 文件不存在安全返回空数组 ✅/❌
- clear 不删除非消息数据 ✅/❌
- 写入失败能向 UI 暴露安全错误 ✅/❌
- 如涉及 Application Support，说明是否需要 isExcludedFromBackup ✅/❌

### 7. Realism & Product Boundary Review

- 不能把角色写成 AI 女友 ✅/❌
- 不能默认恋爱关系 ✅/❌
- 不能使用亲密称呼 ✅/❌
- 不能让角色假装真人 ✅/❌
- 不能让角色声称真实线下活动/地理位置/真实身体 ✅/❌
- 不能把 App 写成 ChatGPT 套壳 ✅/❌
- 默认角色仍应是"虚拟网友 / 项目搭档" ✅/❌
- 如改 prompt，必须说明是否影响真实感边界 ✅/❌

### 8. Build & Static Check

**必须实际运行：**

```
xcodegen generate
xcodebuild
secret scan (grep sk-)
git status
```

**如任务涉及新增文件或重构，还必须：**

```
grep 检查 API Key / secret / sk- 泄露
grep 检查 UserDefaults 是否误存 Key
grep 检查 prompt 是否误包含 baseURL/modelName/apiKey
grep 检查是否误引入 Memory/WorldBook/RAG/Life Scheduler/主动消息等越界模块
```

### 9. Diff Review

输出报告前审查 `git diff`，并在 Dev Report 中概括：
- 每个文件为什么修改
- 是否存在无关 diff
- 是否存在自动格式化导致的大面积无关修改
- 是否存在 xcodeproj 生成变化
- 是否建议提交这些变化

**如果发现无关 diff，必须回滚。**

### 10. Final Self-verdict

Dev Report 末尾必须给出明确结论：

| Gate | Result |
|------|--------|
| Scope Gate | Pass / Fail |
| Architecture Gate | Pass / Fail |
| Privacy & Security Gate | Pass / Fail |
| Error Handling Gate | Pass / Fail |
| State & Concurrency Gate | Pass / Fail |
| Persistence Gate | Pass / Fail |
| Realism Gate | Pass / Fail |
| Build Gate | Pass / Fail |

**只要任一 Gate 为 Fail，本轮不得声称"完成"，必须说明失败原因和建议修复任务。**

### 禁止事项

- 禁止伪造命令结果
- 禁止把"应该可以运行"写成 build 通过
- 禁止没有运行 xcodebuild 就写 BUILD SUCCEEDED
- 禁止隐藏失败命令
- 禁止用大段解释掩盖未完成项
- 禁止自动进入下一任务
