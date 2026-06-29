import SwiftUI

/// 聊天记录按日期只读浏览器。branch-aware，复用 hidden filtering。
struct ChatHistoryDateBrowserView: View {
    @State private var sections: [DaySection] = []
    @State private var branchTitle: String = ""

    let messages: [ChatMessage]
    let branchName: String

    init(messages: [ChatMessage], branchName: String) {
        self.messages = messages
        self.branchName = branchName
    }

    var body: some View {
        Group {
            if sections.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("当前分支没有聊天记录")
                        .foregroundStyle(.secondary)
                    Text(branchName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sections) { section in
                        Section {
                            ForEach(section.messages) { message in
                                ChatHistoryRowView(message: message)
                            }
                        } header: {
                            HStack {
                                Text(section.displayTitle)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(section.messages.count) 条")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("聊天记录")
        .onAppear {
            sections = DaySection.build(from: messages)
            branchTitle = branchName
        }
    }
}

// MARK: - Day Section

struct DaySection: Identifiable {
    let id: String       // "yyyy-MM-dd"
    let displayTitle: String
    let date: Date
    let messages: [ChatMessage]

    static func build(from messages: [ChatMessage]) -> [DaySection] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")

        let grouped = Dictionary(grouping: messages) { msg -> String in
            let day = calendar.startOfDay(for: msg.createdAt)
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: day)
        }

        return grouped.compactMap { key, msgs -> DaySection? in
            guard let date = msgs.first?.createdAt else { return nil }
            let day = calendar.startOfDay(for: date)
            let displayTitle: String
            if calendar.isDate(day, inSameDayAs: today) {
                displayTitle = "今天"
            } else if calendar.isDate(day, inSameDayAs: yesterday) {
                displayTitle = "昨天"
            } else {
                df.dateFormat = "yyyy年M月d日"
                displayTitle = df.string(from: day)
            }
            return DaySection(
                id: key,
                displayTitle: displayTitle,
                date: day,
                messages: msgs.sorted { $0.createdAt < $1.createdAt }
            )
        }
        .sorted { $0.date > $1.date }
    }
}

// MARK: - Row

private struct ChatHistoryRowView: View {
    let message: ChatMessage

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(message.role == .user ? "你" : "对方")
                    .font(.caption)
                    .foregroundStyle(message.role == .user ? .blue : .orange)
                Text(timeFormatter.string(from: message.createdAt))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }
}
