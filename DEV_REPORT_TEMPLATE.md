# DEV_REPORT_TEMPLATE

> 每轮任务完成后必须按此模板输出报告。与 REVIEW_GATE.md 的 Required Report Add-on 兼容。

## Template (Markdown)

每轮报告必须包含以下全部章节。不可跳过。

~~~~md
## Dev Report — Task [编号]

### Task

[任务编号 + 名称，如 Task 0.5: Implement Keychain Storage v0]

### Summary

[一句话描述本轮做了什么。非技术语言，用户可读懂。]

### Files Changed

[列出所有修改的文件。标注：新增 / 修改 / 删除。]

* `Core/Security/KeychainManager.swift` — 新增
* `Core/Security/KeychainError.swift` — 新增

### Behavior

[用户能看到什么变化。没有视觉变化就写"无用户可见变化"。]

* 用户可以在设置页面保存 API Key。
* API Key 不会在日志或 UserDefaults 中出现。

### Tests / Checks

#### Actually Run

[列出实际运行的命令和结果。必须包含具体命令。]

```
$ swift build
Build complete! (0.23s)

$ grep -r "UserDefaults" --include="*.swift" . | grep -i key
[空输出 — 通过]

$ grep -r "sk-" --include="*.swift" .
[空输出 — 通过]
```

#### Not Run

[列出未运行的检查及原因。不能说"没环境"就跳过。]

* `xcodebuild` — 未安装 Xcode。替代：手动检查了所有 .swift 文件的语法。
* 模拟器测试 — 无 Xcode 模拟器。替代：代码已写，手动 review 调用路径。

### Review Gate Result

#### Scope Gate
Pass/Fail: Pass
Evidence: 只实现了 KeychainManager 的三个方法。未触碰 MVP_SCOPE.md "明确不做"清单中的任何项目。

#### Code Gate
Pass/Fail: Pass
Evidence: 代码可编译。无硬编码 Key。无死代码。错误处理已实现（KeychainError enum）。

#### Privacy & Security Gate
Pass/Fail: Pass
Evidence: `grep` 确认无 UserDefaults 存 Key、无日志打印 Key、无硬编码 Key。

#### Realism Gate
Pass/Fail: N/A
Evidence: 本轮是实现 Keychain 存储，不涉及聊天体验/prompt/角色行为。

### Risks

[本轮引入或发现的风险。]

* 无。

### Out of Scope

[明确说明本轮没有做的、但可能看起来相关的功能。防止用户以为漏了。]

* 没有实现 Provider 调用。
* 没有实现 UI 页面。
* 没有实现多个 Provider 切换。

### Next Suggested Task

[建议下一个执行的任务编号。]

Task 0.6: Build Provider Settings UI

### Commit Message

```
feat(Task 0.5): 实现 API Key 的 Keychain 安全存储

- KeychainManager: save/get/delete 三个方法
- KeychainError 错误类型
- 不使用 UserDefaults
- 不打印 Key 到日志

Co-Authored-By: Claude <noreply@anthropic.com>
```

---

本轮完成，等待用户确认。
请回复：通过 / 不通过 / 继续下一个任务。
~~~~

## Compatibility with REVIEW_GATE.md

此模板与 REVIEW_GATE.md 的 Required Report Add-on 完全兼容。

模板中的以下段落直接对应 REVIEW_GATE.md 的 Review Gate Result：

- **Scope Gate** → `### Scope Gate`
- **Architecture Gate** → `### Architecture Gate`
- **Code Gate** → `### Code Gate`
- **Privacy & Security Gate** → `### Privacy & Security Gate`
- **Error Handling Gate** → `### Error Handling Gate`
- **State & Concurrency Gate** → `### State & Concurrency Gate`
- **Persistence Gate** → `### Persistence Gate`
- **Realism Gate** → `### Realism Gate`
- **Build Gate** → `### Build Gate`
- **Tests / Checks → Actually Run** → `### Checks Actually Run`
- **Tests / Checks → Not Run** → `### Checks Not Run`

## Checklist Before Submitting

提交报告前，执行者必须逐项自查：

- [ ] Task 编号正确。
- [ ] Summary 非技术语言，用户可读。
- [ ] Files Changed 完整（没有漏掉修改的文件）。
- [ ] Behavior 说明了用户可见变化（或明确写了"无"）。
- [ ] Actually Run 包含具体命令和结果。
- [ ] Not Run 包含原因说明。
- [ ] 8 个 Gate 全部填写（包括 N/A 的说明）：Scope / Architecture / Code / Privacy & Security / Error Handling / State & Concurrency / Persistence / Realism / Build。
- [ ] Risks 不为空（至少写了"无"）。
- [ ] Out of Scope 说明了明确没有做的相关功能。
- [ ] Next Suggested Task 给出了具体任务编号。
- [ ] Commit Message 简洁描述了改动。
- [ ] 报告末尾有"本轮完成，等待用户确认"。
- [ ] 没有"应该没问题""理论上可运行"。
- [ ] 没有"我已确保"无证据。
