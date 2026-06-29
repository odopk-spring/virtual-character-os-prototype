import Foundation

enum WorldBookKeywordSuggestionError: Error, Equatable {
    case emptyInput
    case providerNotConfigured
    case emptyResponse
    case noUsableKeywords
}

struct WorldBookKeywordSuggestionService {
    private let provider: any LLMProvider

    init(provider: any LLMProvider = OpenAICompatibleProvider()) {
        self.provider = provider
    }

    func suggestKeywords(title: String, content: String) async throws -> [String] {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty || !trimmedContent.isEmpty else {
            throw WorldBookKeywordSuggestionError.emptyInput
        }

        let config = Self.readProviderConfig()
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw WorldBookKeywordSuggestionError.providerNotConfigured
        }

        let request = ChatRequest(
            messages: [
                ChatRequestMessage(role: .system, content: Self.keywordExtractorInstruction),
                ChatRequestMessage(role: .user, content: Self.userPrompt(title: trimmedTitle, content: trimmedContent))
            ],
            temperature: 0.2,
            maxTokens: 180
        )

        let response = try await provider.send(request, config: config)
        let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            throw WorldBookKeywordSuggestionError.emptyResponse
        }

        let parsed = Self.parseKeywords(from: raw)
        guard !parsed.isEmpty else {
            throw WorldBookKeywordSuggestionError.noUsableKeywords
        }
        return parsed
    }

    // MARK: - Config

    private static func readProviderConfig() -> ProviderConfig {
        let defaults = UserDefaults.standard
        return ProviderConfig(
            baseURL: defaults.string(forKey: "ProviderSettings.baseURL") ?? "",
            modelName: defaults.string(forKey: "ProviderSettings.modelName") ?? "",
            providerName: defaults.string(forKey: "ProviderSettings.providerName") ?? "OpenAI-compatible",
            apiKeyStoredInKeychain: false
        )
    }

    // MARK: - Prompt

    private static let keywordExtractorInstruction = """
    你是一个关键词提取器。请根据世界书条目的标题和内容，生成 5 到 10 个适合作为触发词的中文关键词。
    要求：
    1. 只返回关键词。
    2. 优先返回 JSON 字符串数组，例如 ["关键词1","关键词2"]。
    3. 不要解释。
    4. 不要 markdown。
    5. 不要输出完整句子。
    6. 关键词应短，通常 2 到 8 个字。
    7. 可以包含人物、地点、关系、事件、物品、行为规则、语气规则等相关触发词。
    """

    private static func userPrompt(title: String, content: String) -> String {
        """
        标题：\(title)
        内容：\(content)
        """
    }

    // MARK: - Parsing

    static func parseKeywords(from raw: String) -> [String] {
        let cleaned = stripCodeFence(raw)

        if let jsonKeywords = parseJSONKeywords(from: cleaned), !jsonKeywords.isEmpty {
            return normalizeKeywords(jsonKeywords)
        }

        let normalizedSeparators = cleaned
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "、", with: ",")
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "；", with: ",")
            .replacingOccurrences(of: "\n", with: ",")

        let pieces = normalizedSeparators
            .components(separatedBy: ",")
            .flatMap { splitNumberedList($0) }

        return normalizeKeywords(pieces)
    }

    private static func stripCodeFence(_ text: String) -> String {
        text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseJSONKeywords(from text: String) -> [String]? {
        guard let data = text.data(using: .utf8) else { return nil }

        if let array = try? JSONDecoder().decode([String].self, from: data) {
            return array
        }

        if let object = try? JSONDecoder().decode(KeywordObject.self, from: data) {
            return object.keywords
        }

        return nil
    }

    private static func splitNumberedList(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "0123456789.、)）"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func normalizeKeywords(_ rawKeywords: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for raw in rawKeywords {
            let keyword = sanitizeKeyword(raw)
            guard isUsableKeyword(keyword),
                  seen.insert(keyword.lowercased()).inserted else {
                continue
            }
            result.append(keyword)
            if result.count >= 10 { break }
        }

        return result
    }

    private static func sanitizeKeyword(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’[]{}"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isUsableKeyword(_ keyword: String) -> Bool {
        guard !keyword.isEmpty, keyword.count <= 12 else { return false }
        if keyword.contains("http://") || keyword.contains("https://") { return false }
        if keyword.lowercased().contains("api_key") || keyword.lowercased().contains("bearer") { return false }
        if keyword.contains("：") || keyword.contains(":") { return false }
        let punctuationCount = keyword.filter { $0.isPunctuation }.count
        return punctuationCount <= 1
    }

    private struct KeywordObject: Decodable {
        let keywords: [String]
    }
}
