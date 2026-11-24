
import SwiftUI

@main
struct WeChatStyleDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

struct DemoMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var incoming: Bool
    var time = Date()
}

struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ChatListView()
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

struct ChatListView: View {
    private let chats = [
        ("文件传输助手", "文件已发送", "09:30"),
        ("演示联系人", "你好，欢迎使用演示应用", "昨天"),
        ("群聊演示", "大家早上好", "星期一")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(chats, id: \.0) { chat in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: "message.fill")
                                    .foregroundStyle(.green)
                                    .font(.title2)
                            }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(chat.0)
                                .font(.system(size: 16, weight: .medium))

                            Text(chat.1)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(chat.2)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            .listStyle(.plain)
            .navigationTitle("微信")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "plus.circle")
                }
            }
        }
    }
}
