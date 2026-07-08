# VirtualCharacterOS

An open-source iOS prototype for a virtual character agent: BYOK model access,
long-term memory, world-book context, natural chat rhythm, narration blocks, and
voice-message playback experiments.

This repository is a prototype, not a production service. It intentionally keeps
API keys out of source control: model credentials are entered by the user and
stored in the iOS Keychain. The optional local TTS server is for development
testing and exposes a small `/v1/tts` interface that returns MP3 audio.

## Prototype Features

- SwiftUI chat UI with multi-bubble assistant delivery.
- OpenAI-compatible BYOK chat provider.
- Character profile, manual memories, world-book entries, and branchable chat history.
- Reply-length controls and narration display mode.
- iPhone on-device speech playback and optional local/private TTS proxy support.
- Local JSON persistence in the app sandbox.

## Quick Start

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project VirtualCharacterOS.xcodeproj \
  -scheme VirtualCharacterOS \
  -destination 'generic/platform=iOS Simulator' build
```

Open `VirtualCharacterOS.xcodeproj` in Xcode, run the app, then configure your
OpenAI-compatible provider in Settings. Do not commit API keys or local `.env`
files.

## Optional Local TTS Server

The `tts-server/` folder contains a development-only macOS `say` based mock TTS
server. It helps test the app's voice-message UI before connecting a paid or
private TTS provider.

```bash
cd tts-server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn server:app --host 127.0.0.1 --port 8000
```

For physical iPhone testing, run the server on `0.0.0.0` and use your Mac's LAN
IP in the app settings.

## License

MIT. See [LICENSE](LICENSE).

---

# iOS 虚拟人物生态 App — 完整产品技术蓝图

> 版本：v1.0 | 日期：2026-06-27 | 状态：PRD 草案

## 一句话定义

> 一个 iOS 上的虚拟人物生命系统。用户通过 BYOK 接入大模型，App 负责让虚拟人物拥有长期记忆、世界设定、时间流、主动行为和关系演化，从而形成像真实网友一样连续自然的互动体验。

## 文档导航

| 编号 | 章节 | 文件 |
|------|------|------|
| 01 | 产品定位 | [01-product-positioning.md](01-product-positioning.md) |
| 02 | 核心体验原则 | [02-core-experience-principles.md](02-core-experience-principles.md) |
| 03 | 总体架构 | [03-system-architecture.md](03-system-architecture.md) |
| 04 | 模块详解（14个子模块） | [04-module-details.md](04-module-details.md) |
| 05 | 记忆系统设计（核心） | [05-memory-system.md](05-memory-system.md) |
| 06 | 世界书设计（核心） | [06-world-book.md](06-world-book.md) |
| 07 | Context Builder 设计（核心） | [07-context-builder.md](07-context-builder.md) |
| 08 | 时间流系统设计（核心） | [08-life-scheduler.md](08-life-scheduler.md) |
| 09 | 主动消息系统设计 | [09-proactive-messaging.md](09-proactive-messaging.md) |
| 10 | 关系演化系统设计 | [10-relationship-dynamics.md](10-relationship-dynamics.md) |
| 11 | 真实感控制器设计 | [11-realism-engine.md](11-realism-engine.md) |
| 12 | BYOK 与 API 架构 | [12-byok-api-layer.md](12-byok-api-layer.md) |
| 13 | iOS 技术架构 | [13-ios-tech-architecture.md](13-ios-tech-architecture.md) |
| 14 | UI/UX 设计 | [14-ui-ux.md](14-ui-ux.md) |
| 15 | 开源参考方向 | [15-open-source-references.md](15-open-source-references.md) |
| 16 | 商业模式与价格样例 | [16-business-model.md](16-business-model.md) |
| 17 | MVP 路线图 | [17-mvp-roadmap.md](17-mvp-roadmap.md) |
| 18 | 数据模型草案 | [18-data-models.md](18-data-models.md) |
| 19 | 样例集 | [19-examples.md](19-examples.md) |
| 20 | 绝对禁止事项（50条红线） | [20-prohibited-items.md](20-prohibited-items.md) |
| 21 | 第一阶段建议执行任务 | [21-phase-one-tasks.md](21-phase-one-tasks.md) |

## 阅读顺序建议

1. 先读 01 产品定位 → 02 核心体验原则 → 03 总体架构，建立全局认知
2. 再读 05 记忆系统 → 06 世界书 → 07 Context Builder，理解核心引擎
3. 然后 08 时间流 → 09 主动消息 → 10 关系演化 → 11 真实感控制器，理解体验层
4. 接着 12 BYOK → 13 iOS 技术架构，理解技术落地
5. 再看 16 商业模式 → 17 MVP 路线图 → 21 第一阶段任务，规划执行
6. 最后读 20 禁止事项，确保不踩红线

## 核心设计理念

**这个产品不是聊天机器人，而是虚拟人物的运行时（Virtual Character Runtime）。**

- Chat 只是交互界面，真正的产品是角色的记忆、时间、关系、世界和主动性系统
- 真实感不靠长回复实现，靠时间流、记忆一致性、人格边界、主动性、生活感和关系演化
- BYOK 模式让用户拥有数据和隐私主权，App 专注做体验基础设施
