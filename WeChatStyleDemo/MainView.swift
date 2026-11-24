
import SwiftUI

@main
struct WeChatStyleDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

// MARK: - Message Model

struct DemoMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var incoming: Bool
    var time = Date()
}

// MARK: - Chat Model

struct DemoChat: Identifiable, Codable {
    var id = UUID()
    var name: String
    var messages: [DemoMessage]
    var updatedAt = Date()

    var preview: String {
        messages.last?.text ?? "暂无消息"
    }
}

// MARK: - Chat Storage

class ChatStore: ObservableObject {
    @Published var chats: [DemoChat] = [] {
        didSet {
            save()
        }
    }

    private let storageKey = "WeChatStyleDemo.Chats"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([DemoChat].self, from: data) {
            chats = saved
        }

        if chats.isEmpty {
            chats = [
                DemoChat(
                    name: "文件传输助手",
                    messages: [
                        DemoMessage(
                            text: "文件已发送",
                            incoming: true
                        )
                    ]
                ),
                DemoChat(
                    name: "演示联系人",
                    messages: [
                        DemoMessage(
                            text: "你好，欢迎使用演示应用",
                            incoming: true
                        )
                    ]
                ),
                DemoChat(
                    name: "群聊演示",
                    messages: [
                        DemoMessage(
                            text: "大家早上好",
                            incoming: true
                        )
                    ]
                )
            ]
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(chats) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func send(_ text: String, to chatID: UUID) {
        guard let index = chats.firstIndex(where: {
            $0.id == chatID
        }) else {
            return
        }

        let message = DemoMessage(
            text: text,
            incoming: false
        )

        chats[index].messages.append(message)
        chats[index].updatedAt = Date()
    }

    func addChat() {
        let newChat = DemoChat(
            name: "新建会话 \(chats.count + 1)",
            messages: [
                DemoMessage(
                    text: "你好！这是一个新的演示会话。",
                    incoming: true
                )
            ]
        )

        chats.insert(newChat, at: 0)
    }
}

// MARK: - Main View

struct MainView: View {
    @State private var selectedTab = 0
    @StateObject private var store = ChatStore()

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView(store: store)
                .tabItem {
                    Label("微信", systemImage: "message")
                }
                .tag(0)

            Text("通讯录")
                .tabItem {
                    Label("通讯录", systemImage: "person.2")
                }
                .tag(1)

            Text("发现")
                .tabItem {
                    Label("发现", systemImage: "safari")
                }
                .tag(2)

            Text("我")
                .tabItem {
                    Label("我", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .tint(.green)
    }
}

// MARK: - Chat List

struct ChatListView: View {
    @ObservedObject var store: ChatStore
    @State private var searchText = ""

    private var filteredChats: [DemoChat] {
        let sorted = store.chats.sorted {
            $0.updatedAt > $1.updatedAt
        }

        if searchText.isEmpty {
            return sorted
        }

        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredChats) { chat in
                    NavigationLink(value: chat.id) {
                        ChatRowView(chat: chat)
                    }
                    .listRowSeparator(.visible)
                }
            }
            .listStyle(.plain)
            .navigationTitle("微信")
            .searchable(
                text: $searchText,
                prompt: "搜索"
            )
            .navigationDestination(for: UUID.self) { chatID in
                ChatDetailView(
                    store: store,
                    chatID: chatID
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.addChat()
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                    }
                }
            }
        }
    }
}

// MARK: - Chat Row

struct ChatRowView: View {
    let chat: DemoChat

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.18))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "message.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }

            VStack(alignment: .leading, spacing: 7) {
                Text(chat.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.primary)

                Text(chat.preview)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(chat.updatedAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Chat Detail

struct ChatDetailView: View {
    @ObservedObject var store: ChatStore
    let chatID: UUID

    @State private var draft = ""

    private var chat: DemoChat? {
        store.chats.first {
            $0.id == chatID
        }
    }

    var body: some View {
        Group {
            if let chat = chat {
                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(chat.messages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .background(Color(uiColor: .systemGroupedBackground))
                        .onChange(of: chat.messages.count) { _, _ in
                            if let last = chat.messages.last {
                                withAnimation {
                                    proxy.scrollTo(
                                        last.id,
                                        anchor: .bottom
                                    )
                                }
                            }
                        }
                    }

                    messageInput
                }
            } else {
                ContentUnavailableView(
                    "会话不存在",
                    systemImage: "message"
                )
            }
        }
        .navigationTitle(chat?.name ?? "聊天")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messageInput: some View {
        HStack(spacing: 10) {
            TextField("输入消息...", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button {
                sendMessage()
            } label: {
                Text("发送")
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(
                        draft.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty ? Color.gray : Color.green
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(
                draft.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !text.isEmpty else {
            return
        }

        store.send(text, to: chatID)
        draft = ""
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: DemoMessage

    var body: some View {
        HStack {
            if message.incoming {
                bubble
                Spacer(minLength: 50)
            } else {
                Spacer(minLength: 50)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(message.text)
                .font(.system(size: 16))
                .foregroundStyle(
                    message.incoming ? Color.primary : Color.white
                )

            Text(message.time, style: .time)
                .font(.system(size: 10))
                .foregroundStyle(
                    message.incoming
                    ? Color.secondary
                    : Color.white.opacity(0.75)
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            message.incoming
            ? Color(uiColor: .secondarySystemBackground)
            : Color.green
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
