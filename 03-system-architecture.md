# 03 — 总体架构

## 3.1 架构总览图

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App Layer                            │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────────────┐  │
│  │  Chat UI │ │Character │ │ Memory   │ │   World Book      │  │
│  │          │ │ Status   │ │ Viewer   │ │   Editor          │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───────┬───────────┘  │
│       │            │            │                │              │
├───────┴────────────┴────────────┴────────────────┴──────────────┤
│                    Core Engine Layer                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Context Builder                         │  │
│  │  (组装最终 prompt，管理 token 预算，编排检索)              │  │
│  └──┬───────┬────────┬──────────┬──────────┬───────────────┘  │
│     │       │        │          │          │                   │
│  ┌──┴──┐ ┌──┴──┐ ┌───┴───┐ ┌───┴────┐ ┌───┴──────┐          │
│  │Memory│ │World│ │Time   │ │Relation│ │Realism   │          │
│  │System│ │Book │ │Flow   │ │Dynamics│ │Engine    │          │
│  └──┬──┘ └──┬──┘ └───┬───┘ └───┬────┘ └───┬──────┘          │
│     │       │        │         │           │                  │
│  ┌──┴───────┴────────┴─────────┴───────────┴────┐             │
│  │            Local Data Layer                   │             │
│  │  SQLite/GRDB + File Storage + Keychain        │             │
│  └───────────────────────────────────────────────┘             │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              BYOK Provider Layer                         │  │
│  │  OpenAI │ Anthropic │ DeepSeek │ Gemini │ OpenRouter    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Proactive Messaging Engine                    │  │
│  │  Local Notifications │ APNs (Cloud Life Mode optional)   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │            Safety & Boundary Layer                       │  │
│  │  内容过滤 │ 关系边界 │ 角色一致性 │ 用户保护               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────┐
                    │   Optional Cloud Layer   │
                    │   (Cloud Life Mode)      │
                    │   ┌───────────────────┐  │
                    │   │ User Auth         │  │
                    │   │ Encrypted Sync    │  │
                    │   │ Schedule Worker   │  │
                    │   │ APNs Dispatcher   │  │
                    │   │ Memory Compactor  │  │
                    │   └───────────────────┘  │
                    └─────────────────────────┘
```

## 3.2 模块清单与职责

| 编号 | 模块 | 一句话职责 | MVP 优先级 |
|------|------|-----------|-----------|
| 1 | Character Profile | 存储和管理角色的核心人格定义 | P0 |
| 2 | Memory System | 多层记忆的存储、检索、抽取、遗忘 | P1 |
| 3 | World Book | 世界设定条目的存储和触发式检索 | P1 |
| 4 | Context Builder | 将各模块输出组装为发送给模型的最终 prompt | P0 |
| 5 | Life Scheduler | 管理角色的每日计划、当前状态、时间流逝 | P2 |
| 6 | Proactive Messaging | 触发和生成角色的主动消息 | P2 |
| 7 | Relationship Dynamics | 追踪和演化用户与角色的关系状态 | P1 |
| 8 | Realism Engine | 规则引擎，控制回复风格、长度、延迟等 | P1 |
| 9 | BYOK Provider Layer | 适配不同 API 提供商，统一接口 | P0 |
| 10 | Local Storage | 所有本地数据的持久化 | P0 |
| 11 | Optional Backend | 可选的云端同步和主动消息后端 | P3 |
| 12 | Notification System | 本地通知和远程推送管理 | P2 |
| 13 | Safety & Boundary | 内容安全、用户保护、角色边界 | P1 |
| 14 | UI Layer | 所有用户界面 | P0 |

## 3.3 数据流（用户发消息 → 角色回复）

```
用户发消息
    │
    ▼
┌──────────────────────────────────────────────┐
│ Step 1: Context Builder 启动                 │
│                                              │
│ 1.1 读当前时间 → Life Scheduler              │
│ 1.2 读角色当前状态 → Life Scheduler           │
│ 1.3 读用户消息，做意图/实体/情绪识别           │
│ 1.4 检索短期记忆 → Memory System              │
│ 1.5 检索相关长期记忆 → Memory System          │
│ 1.6 检索相关世界书条目 → World Book           │
│ 1.7 检索当前关系状态 → Relationship Dynamics  │
│ 1.8 获取角色今日计划 → Life Scheduler         │
│ 1.9 应用回复模式判断 → Realism Engine         │
│ 1.10 Token 预算计算                           │
│ 1.11 组装完整 prompt                          │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Step 2: BYOK Provider 发送请求               │
│                                              │
│ 2.1 选择用户配置的 Provider                   │
│ 2.2 适配 prompt 格式（不同 API 差异）          │
│ 2.3 发送请求（流式）                          │
│ 2.4 处理超时/重试/错误                        │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Step 3: 后处理                               │
│                                              │
│ 3.1 保存消息到 Raw Messages                   │
│ 3.2 更新角色状态（心情、精力等）               │
│ 3.3 更新关系指标                              │
│ 3.4 后台触发记忆抽取（异步）                   │
│ 3.5 更新 UI                                  │
└──────────────────────────────────────────────┘
```

## 3.4 数据流（角色主动发消息）

```
┌──────────────────────────────────────────────┐
│               触发源                          │
│                                              │
│ 时间触发 │ 记忆触发 │ 关系触发 │ 生活触发       │
│ 用户事件 │ 长期未联系 │ 特殊日期              │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Proactive Messaging Engine                   │
│                                              │
│ 检查触发条件 → 生成消息 → 频率控制 → 去重 →    │
│ 写入消息记录 → 发送通知                        │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ iOS Notification                             │
│                                              │
│ 纯本地版：UNUserNotificationCenter 本地通知    │
│ 云端版：Backend → APNs → 用户设备              │
└──────────────────────────────────────────────┘
```

## 3.5 模块依赖关系

```
Context Builder
    ├── depends on: Memory System
    ├── depends on: World Book
    ├── depends on: Life Scheduler
    ├── depends on: Relationship Dynamics
    ├── depends on: Realism Engine
    └── depends on: BYOK Provider Layer (发送)

Memory System
    ├── depends on: Local Storage
    └── referenced by: Context Builder

World Book
    ├── depends on: Local Storage
    └── referenced by: Context Builder

Life Scheduler
    ├── depends on: Local Storage
    ├── depends on: Character Profile
    └── referenced by: Context Builder, Proactive Messaging

Relationship Dynamics
    ├── depends on: Memory System (关系记忆)
    └── referenced by: Context Builder

Proactive Messaging
    ├── depends on: Life Scheduler
    ├── depends on: Memory System
    ├── depends on: Relationship Dynamics
    └── depends on: Optional Backend (云端版)

Realism Engine
    └── referenced by: Context Builder

BYOK Provider Layer
    └── depends on: Keychain (API Keys)
```

## 3.6 两种部署模式

### 模式 A：Local Mode（纯本地）

```
用户设备上运行一切
  ├── 所有数据本地存储
  ├── API Key 存 Keychain，直接调用模型 API
  ├── 主动消息：本地通知 + 后台刷新（不稳定）
  ├── 时间流：App 打开时补算
  └── 无服务器成本，强隐私
```

适用：隐私敏感用户、高级用户、BYOK 原教旨主义者

### 模式 B：Cloud Life Mode（轻后端）

```
用户设备（主） + 轻量云端（辅）
  ├── 对话和核心数据本地为主，可选云端加密同步
  ├── API Key 用户可选择加密上传（用于云端触发主动消息）
  ├── 主动消息：后端 Schedule Worker → APNs
  ├── 时间流：云端 worker 持续运行角色日程
  ├── 云端：仅做日程调度 + 推送触发 + 加密同步
  │          不做对话代理（API 调用仍在本地或用户代理）
  └── 低服务器成本（无 GPU，仅轻量 worker）
```

适用：需要稳定主动消息、多设备同步的用户

**关键原则：Cloud Life Mode 的服务器不代理对话。对话的 API 调用始终由用户设备发起，或用户显式授权服务器使用加密存储的 API Key 仅用于主动消息生成。**

## 3.7 技术栈

| 层 | 技术选择 | 理由 |
|----|---------|------|
| UI | SwiftUI | iOS 原生，声明式，Apple 主推 |
| 本地数据库 | GRDB（基于 SQLite） | 比 SwiftData 更成熟可控，适合复杂查询 |
| 向量存储 | 本地 NSData + brute force / faiss 可选 | MVP 阶段内存向量检索足够 |
| Keychain | Apple Keychain Services | API Key 安全存储 |
| 网络 | URLSession + async/await | 原生，支持流式 |
| 通知 | UserNotifications + 可选 APNs | iOS 标准 |
| 后台 | BGTaskScheduler + 可选云端 worker | iOS 后台限制下的最优解 |
| 云端（可选）| Vapor / Node.js 轻量后端 | 仅做调度和推送 |

## 3.8 关键架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 本地优先 vs 云端优先 | 本地优先 | BYOK 隐私承诺的核心 |
| SwiftData vs GRDB | GRDB | 复杂记忆系统需要 SQL 级别的控制 |
| 嵌入模型本地 vs API | MVP 用 API，后期可选本地 | 降低 MVP 复杂度 |
| 实时后台 vs 补算 | 补算为主 | iOS 后台限制，补算更可靠 |
| 单体 vs 模块化 | 模块化本地包 + 协议抽象 | 每个模块可独立测试和替换 |
