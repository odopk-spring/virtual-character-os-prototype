import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ChatView(store: Self.makeMessageStore())
        }
    }

    private static func makeMessageStore() -> any MessageStore {
        do {
            return try FileMessageStore()
        } catch {
            return try! FileMessageStore(directory: FileManager.default.temporaryDirectory)
        }
    }
}

#Preview {
    ContentView()
}
