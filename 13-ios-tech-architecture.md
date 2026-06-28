# 13 — iOS 技术架构

## 13.1 技术栈选型

| 层 | 技术 | 理由 |
|----|------|------|
| UI | SwiftUI | Apple 主推，声明式，与各模块的 ObservableObject 天然契合 |
| 导航 | NavigationStack (iOS 16+) | 现代 SwiftUI 导航 |
| 本地数据库 | GRDB (SQLite wrapper) | 比 SwiftData 更成熟，适合复杂查询和迁移 |
| 向量存储 | 初期无，后期可加本地 faiss/加速框架 | MVP 用关键词检索足够 |
| Keychain | Security framework (原生) | API Key 安全存储 |
| 网络 | URLSession + async/await | 原生，支持流式 (bytes.lines) |
| 通知 | UserNotifications + ActivityKit | 本地通知 + 灵动岛（可选） |
| 后台 | BGTaskScheduler | iOS 允许的后台任务（不可靠但聊胜于无） |
| 加密 | CryptoKit | 端到端加密（Cloud Life Mode） |
| 依赖管理 | Swift Package Manager | Apple 原生，无需 CocoaPods |

## 13.2 项目结构

```
VirtualCharacterApp/
├── App/
│   ├── VirtualCharacterApp.swift      // @main entry
│   ├── AppDelegate.swift              // 通知、后台任务注册
│   └── SceneDelegate.swift (可选)
│
├── Core/                              // 核心引擎（无 UI 依赖）
│   ├── Character/
│   │   ├── CharacterProfile.swift     // 数据模型
│   │   ├── CharacterStore.swift       // CRUD
│   │   └── CharacterTemplate.swift    // 预设模板
│   │
│   ├── Memory/
│   │   ├── MemoryItem.swift           // 数据模型
│   │   ├── MemoryStore.swift          // GRDB 操作
│   │   ├── MemoryExtractor.swift      // 抽取引擎
│   │   ├── MemoryRanker.swift         // 排序算法
│   │   └── DecayEngine.swift          // 遗忘引擎
│   │
│   ├── WorldBook/
│   │   ├── WorldBookEntry.swift       // 数据模型
│   │   ├── WorldBookStore.swift       // CRUD
│   │   ├── TriggerEngine.swift        // 触发匹配
│   │   └── WorldBookImporter.swift    // 导入（JSON/Markdown）
│   │
│   ├── ContextBuilder/
│   │   ├── ContextBuilder.swift       // 主编排器
│   │   ├── PromptAssembler.swift      // prompt 组装
│   │   ├── TokenBudget.swift          // token 预算管理
│   │   └── MessageAnalyzer.swift      // 用户消息分析
│   │
│   ├── LifeScheduler/
│   │   ├── LifeScheduler.swift        // 日程管理
│   │   ├── DailyPlanGenerator.swift   // 计划生成
│   │   ├── StateResolver.swift        // 状态解析+补算
│   │   └── ResponseDelay.swift        // 延迟策略
│   │
│   ├── ProactiveMessaging/
│   │   ├── TriggerChecker.swift       // 触发条件
│   │   ├── ProactiveGenerator.swift   // 消息生成
│   │   └── FrequencyController.swift  // 频率控制
│   │
│   ├── Relationship/
│   │   ├── RelationshipState.swift    // 数据模型
│   │   ├── RelationshipStore.swift    // CRUD
│   │   └── EvolutionEngine.swift      // 演化规则
│   │
│   ├── Realism/
│   │   ├── RealismEngine.swift        // 真实感规则
│   │   ├── ResponseModeDecider.swift  // 回复模式决策
│   │   └── StyleRules.swift           // 风格规则
│   │
│   ├── Provider/
│   │   ├── LLMProvider.swift          // 协议定义
│   │   ├── OpenAIProvider.swift
│   │   ├── AnthropicProvider.swift
│   │   ├── DeepSeekProvider.swift
│   │   ├── GeminiProvider.swift
│   │   ├── CustomProvider.swift
│   │   ├── ProviderRegistry.swift     // Provider 注册与选择
│   │   └── KeychainManager.swift      // API Key 管理
│   │
│   ├── Safety/
│   │   ├── SafetyLayer.swift          // 安全/边界层
│   │   └── ContentFilter.swift        // 内容过滤
│   │
│   └── Storage/
│       ├── Database.swift             // GRDB 数据库管理
│       ├── MigrationManager.swift     // 数据库迁移
│       └── ExportImport.swift         // 数据导入导出
│
├── UI/                                // 用户界面
│   ├── Chat/
│   │   ├── ChatView.swift
│   │   ├── ChatViewModel.swift
│   │   ├── MessageBubble.swift
│   │   ├── MessageInputBar.swift
│   │   └── CharacterStatusBar.swift   // 聊天页顶部状态条
│   │
│   ├── Character/
│   │   ├── CharacterListView.swift
│   │   ├── CharacterEditorView.swift
│   │   └── CharacterStatusView.swift
│   │
│   ├── Memory/
│   │   ├── MemoryListView.swift
│   │   ├── MemoryDetailView.swift
│   │   └── MemoryEditView.swift
│   │
│   ├── WorldBook/
│   │   ├── WorldBookListView.swift
│   │   └── WorldBookEditView.swift
│   │
│   ├── Relationship/
│   │   └── RelationshipView.swift
│   │
│   ├── Timeline/
│   │   └── TimelineView.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── APIKeySettingsView.swift
│   │   ├── NotificationSettingsView.swift
│   │   └── PrivacyDataView.swift
│   │
│   └── Common/
│       ├── MarkdownTextView.swift
│       └── StatusBadge.swift
│
├── Cloud/ (可选)
│   ├── CloudSyncManager.swift
│   ├── EncryptionManager.swift
│   └── APNsManager.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── CharacterTemplates/           // 预置角色模板
    │   ├── friend_study.json
    │   ├── friend_daily.json
    │   └── partner_work.json
    └── WorldBookTemplates/           // 预置世界书模板
        └── modern_student.json
```

## 13.3 数据层架构

```swift
// 全局数据库访问
class Database {
    static let shared = Database()
    
    let dbPool: DatabasePool
    
    init() {
        // 数据库文件路径
        let path = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("virtual_character.sqlite")
            .path
        
        // 配置
        var config = Configuration()
        config.prepareDatabase { db in
            // 启用 WAL 模式（更好的并发性能）
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            // 启用外键
            try db.execute(sql: "PRAGMA foreign_keys=ON")
        }
        
        self.dbPool = try! DatabasePool(path: path, configuration: config)
        
        // 执行迁移
        try! MigrationManager.migrate(dbPool)
    }
}

// 使用示例
extension MemoryStore {
    func fetchRecent(characterId: String, limit: Int) async throws -> [MemoryItem] {
        return try await Database.shared.dbPool.read { db in
            try MemoryItem
                .filter(Column("characterId") == characterId)
                .filter(Column("status") == MemoryStatus.active.rawValue)
                .filter(Column("decayScore") > 0.3)
                .order(Column("lastAccessedAt").desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
}
```

## 13.4 数据安全

```
存储安全：
├── API Key → Keychain（系统级加密）
├── 对话数据 → SQLite 文件（iOS 沙盒隔离）
├── 用户设置 → SQLite
└── 导出文件 → 用户选择位置

传输安全：
├── 所有 API 调用 → HTTPS
├── 云端同步（可选）→ E2E 加密 + HTTPS
└── 不上传数据到任何非必要服务器

用户权利：
├── 随时导出所有数据（JSON/Markdown）
├── 随时删除所有数据
├── 随时撤销云端授权
└── App 删除时 Keychain 数据同步清除（iOS 行为）
```

## 13.5 性能考虑

### 需要注意的瓶颈

1. **记忆检索**：当记忆条目超过 1000 条时，向量检索（如果加入）可能变慢。MVP 阶段用关键词+时间排序足够
2. **流式渲染**：SwiftUI 的 Text 在大量更新时可能掉帧。考虑合并更新频率
3. **数据库写入**：GRDB WAL 模式已经很好，但大量异步写入要控制并发
4. **Embedding API 调用**：如果每次检索都调用 embedding API，成本会累积。可以考虑本地 embedding 模型

### 优化策略

```
- 记忆抽取：后台异步执行，不阻塞 UI
- 世界书触发：缓存最近触发结果，冷却期内不重复计算
- Context Builder：并行检索各模块
- 消息列表：虚拟滚动（ForEach + id），避免加载全部历史
- 图片/头像：懒加载 + 内存缓存
```
