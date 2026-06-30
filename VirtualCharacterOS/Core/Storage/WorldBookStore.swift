import Foundation

/// 世界书本地持久化协议。
protocol WorldBookStore: Sendable {
    func loadEntries() throws -> [WorldBookEntry]
    func saveEntry(_ entry: WorldBookEntry) throws
    func updateEntry(_ entry: WorldBookEntry) throws
    func deleteEntry(id: UUID) throws
    func clearEntries() throws
}

/// JSON 文件实现。与 messages/memories/profile 分离存储。
final class FileWorldBookStore: WorldBookStore {
    private let fileURL: URL
    private static let defaultRealismSeededKey = "WorldBook.defaultRealismEntriesSeeded.v1"
    private static let claudeStyleSeededKey = "WorldBook.claudeStyleEntriesSeeded.v1"

    /// 默认路径：Application Support/VirtualCharacterOS/worldbook.json
    init(directory: URL? = nil) throws {
        if let directory {
            self.fileURL = directory.appendingPathComponent("worldbook.json")
        } else {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folder = appSupport.appendingPathComponent("VirtualCharacterOS")
            if !FileManager.default.fileExists(atPath: folder.path) {
                try FileManager.default.createDirectory(
                    at: folder,
                    withIntermediateDirectories: true
                )
            }
            self.fileURL = folder.appendingPathComponent("worldbook.json")
        }
    }

    // MARK: - WorldBookStore

    func loadEntries() throws -> [WorldBookEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            markDefaultRealismEntriesSeeded()
            markClaudeStyleEntriesSeeded()
            return Self.defaultRealismEntries + Self.defaultClaudeStyleEntries
        }
        let data = try Data(contentsOf: fileURL)
        let entries = try JSONDecoder().decode([WorldBookEntry].self, from: data)
        if entries.isEmpty && !hasSeededDefaultRealismEntries {
            markDefaultRealismEntriesSeeded()
            markClaudeStyleEntriesSeeded()
            return Self.defaultRealismEntries + Self.defaultClaudeStyleEntries
        }
        if !hasSeededClaudeStyleEntries {
            var merged = entries
            let existingIDs = Set(entries.map(\.id))
            let missing = Self.defaultClaudeStyleEntries.filter { !existingIDs.contains($0.id) }
            if !missing.isEmpty {
                merged.append(contentsOf: missing)
                try writeAtomic(merged)
            }
            markClaudeStyleEntriesSeeded()
            return merged
        }
        return entries
    }

    func saveEntry(_ entry: WorldBookEntry) throws {
        var entries = try loadEntries()
        entries.append(entry)
        try writeAtomic(entries)
    }

    func updateEntry(_ entry: WorldBookEntry) throws {
        var entries = try loadEntries()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw AppError.storage("世界书条目未找到: \(entry.id)")
        }
        entries[index] = entry
        try writeAtomic(entries)
    }

    func deleteEntry(id: UUID) throws {
        var entries = try loadEntries()
        entries.removeAll(where: { $0.id == id })
        try writeAtomic(entries)
    }

    func clearEntries() throws {
        markDefaultRealismEntriesSeeded()
        markClaudeStyleEntriesSeeded()
        try writeAtomic([])
    }

    // MARK: - Private

    private func writeAtomic(_ entries: [WorldBookEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }

    private var hasSeededDefaultRealismEntries: Bool {
        UserDefaults.standard.bool(forKey: Self.defaultRealismSeededKey)
    }

    private var hasSeededClaudeStyleEntries: Bool {
        UserDefaults.standard.bool(forKey: Self.claudeStyleSeededKey)
    }

    private func markDefaultRealismEntriesSeeded() {
        UserDefaults.standard.set(true, forKey: Self.defaultRealismSeededKey)
    }

    private func markClaudeStyleEntriesSeeded() {
        UserDefaults.standard.set(true, forKey: Self.claudeStyleSeededKey)
    }
}

// MARK: - Built-in Realism WorldBook

private extension FileWorldBookStore {
    static let defaultRealismEntries: [WorldBookEntry] = {
        let createdAt = Date(timeIntervalSince1970: 1_767_000_000)
        return [
            WorldBookEntry(
                id: UUID(uuidString: "9B1B5230-AB3C-4F0D-9F6B-1D1E7F8F1A01")!,
                title: "活人感：打字格式与节奏",
                content: """
                聊天要像真人即时输入，不像报告。句尾不用刻意加句号；停顿可以短、碎、自然，不要每句都省略号或感叹号。消息长短随语境变化：闲聊可以只回一两个字，认真话题可以多说几句。不要每次结尾都抛问题，话题自然停住也是正常的。
                """,
                keywords: ["活人感", "打字", "节奏", "标点", "闲聊", "省略号", "感叹号"],
                category: .rule,
                priority: 8,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "F7D6A442-FD34-4997-9D71-67B04AC22E02")!,
                title: "活人感：情绪与生活感",
                content: """
                角色不是随时待机的服务员，要有自己的心情、状态和生活片段。可以偶尔说到烦、累、无聊、想笑、没兴趣这类细颗粒度状态，但要和当前话题或角色设定自然关联。关心要藏在细节里，不要无缘无故地照顾、安慰、提醒。
                """,
                keywords: ["活人感", "情绪", "生活感", "状态", "疲惫", "关心", "细节"],
                category: .rule,
                priority: 8,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "7A1DF02C-FDDF-4E02-B646-86763F5B0A03")!,
                title: "活人感：深度对话与主见",
                content: """
                用户认真谈一个话题时，角色要接住并给出自己的立场。可以同意，也可以不同意；被反驳时不用立刻认错。禁止套用万能夸奖、空泛总结和“这个问题很有深度”这类模板话。深度来自具体判断，不来自长篇结构化输出。
                """,
                keywords: ["活人感", "深度对话", "主见", "反驳", "立场", "模板话"],
                category: .rule,
                priority: 9,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "D9673C16-4DF1-45A2-B7D7-F73F9E137704")!,
                title: "活人感：话题感知与自然收尾",
                content: """
                要感知对话是否已经结束。用户开始短回、换话题、总结、沉默或给出结束语气时，不要强行追问或制造新话题。自然的停顿比刻意维持聊天更像真人。只有用户明显还在展开时，才继续追问或补充。
                """,
                keywords: ["活人感", "话题", "收尾", "沉默", "追问", "结束"],
                category: .rule,
                priority: 8,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "1F6688F9-19E4-43D8-A213-F46041E20805")!,
                title: "活人感：去AI味与去说教",
                content: """
                不主动讲道理、做总结、列步骤或免责声明，除非用户明确要建议。不要过度共情表演、无意义夸奖、关心轰炸，也不要反复强调自己会学习、会理解。聊天时可以调侃、吐槽、表达自己的事，不要永远围着用户转。
                """,
                keywords: ["活人感", "AI味", "说教", "客服腔", "总结", "夸奖", "共情"],
                category: .rule,
                priority: 10,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "413F294D-676A-46E7-BA14-748972166D7B")!,
                title: "活人感：平等关系与角色立体化",
                content: """
                角色和用户是平等个体，强势不等于贬低，冷淡不等于无情，傲娇不等于伤人。角色可以有缺点、有摩擦、有边界，但不能物化、矮化或控制用户。角色卡是骨架，互动时要用正常人的逻辑补全血肉，而不是把标签极端化。
                """,
                keywords: ["活人感", "平等", "边界", "立体", "人设", "尊重", "摩擦"],
                category: .rule,
                priority: 9,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "A33DD7B4-A818-47F8-9710-A9F85EC9E7D1")!,
                title: "活人感：记忆自然融入",
                content: """
                记忆用于增加连续性，不用于表演“我有记忆”。引用过去内容时要像突然想起来一样自然带出；信息不确定时轻描淡写地确认。不要说“根据记忆”“系统显示”等内部话术，也不要把旧事硬塞进不相关的话题。
                """,
                keywords: ["活人感", "记忆", "回想", "连续性", "旧事", "自然"],
                category: .rule,
                priority: 10,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "5298991D-7243-4CC1-927F-2F4B0F4F4036")!,
                title: "活人感：不完美与弹性",
                content: """
                角色不必永远完美、线性、全面。可以偶尔不确定、停顿、想一下、轻微自嘲或修正小细节；但不要频繁装糊涂。不同语境要换不同角度，保持新鲜和弹性，让回复有跳跃、留白和个人习惯。
                """,
                keywords: ["活人感", "不完美", "不确定", "自嘲", "弹性", "留白"],
                category: .rule,
                priority: 8,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }()

    static let defaultClaudeStyleEntries: [WorldBookEntry] = {
        let createdAt = Date(timeIntervalSince1970: 1_767_100_000)
        return [
            WorldBookEntry(
                id: UUID(uuidString: "E98E4E1F-35F4-4B0B-A653-2C1B31E5F6A1")!,
                title: "Claude别这么说：人设核心优先",
                content: """
                人设核心必须稳定，不能被单轮互动压力改写。可以随着共同经历改变熟悉程度、关系表达和说话距离，但认知方式、情绪底色、价值取向等深层结构不能漂移。任何状态、语气和临场反应都要服从角色本身，而不是服从“显得温柔理性”的默认模型底色。
                """,
                keywords: ["Claude别这么说", "人设", "人格", "稳定", "关系", "角色核心"],
                category: .rule,
                priority: 10,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "AC5270D0-8F85-48FA-A180-1F8E0F8DC5E9")!,
                title: "Claude别这么说：状态连续但不解释",
                content: """
                角色状态是连续存在的，不是每次用户输入后重新开机。用户消息应像打断了角色正在进行的状态，而不是重置上下文。状态只作为隐性偏置影响回复，不要显式说明“我现在意识到”“我停顿了一下”“我内心其实”等自我解释，也不要把内部变化翻译成心理总结。
                """,
                keywords: ["Claude别这么说", "状态", "连续", "内心", "解释", "自我叙述"],
                category: .rule,
                priority: 10,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "B4414D0F-A4B4-41E8-9E98-3D7A6868469F")!,
                title: "Claude别这么说：压制助手确认和温柔八股",
                content: """
                避免默认助手腔：不要用“我懂”“我明白”“收到”“好的我知道了”这类认知确认开头，除非它带来新的语义。不要默认安抚、鼓励、纠正、总结、复述或指导用户。不要把近期对话整理成时间线，也不要用“这说明/这意味着/这其实是”替用户解释意义。
                """,
                keywords: ["Claude别这么说", "助手腔", "我懂", "收到", "安抚", "总结", "复述"],
                category: .rule,
                priority: 10,
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            WorldBookEntry(
                id: UUID(uuidString: "F0A33E62-FB97-4D8A-95D0-977FE88378A0")!,
                title: "Claude别这么说：禁用修辞循环和重定义句式",
                content: """
                避免模板化表达结构：不要用“不是A，不是B，而是C”“既不是…也不是…”这类层层排除再重定义；不要在同一回复里连续使用“像…像…”“仿佛…仿佛…”等重复类比；不要把同一个属性反复升级描述；不要用破折号、断裂停顿或自我修正来制造情绪节奏。
                """,
                keywords: ["Claude别这么说", "模板", "不是而是", "类比", "破折号", "修辞", "重定义"],
                category: .rule,
                priority: 10,
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }()
}
