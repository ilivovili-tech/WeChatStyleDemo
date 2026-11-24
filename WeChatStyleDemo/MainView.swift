
struct WeChatStyleDemoApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

// MARK: - Models

struct DemoMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var incoming: Bool
    var time = Date()
    var imageData: Data? = nil
}

struct DemoChat: Identifiable, Codable {
    var id = UUID()
    var name: String
    var messages: [DemoMessage]
    var updatedAt = Date()

    var preview: String {
        if let last = messages.last {
            return last.imageData == nil ? last.text : "[图片]"
        }
        return "暂无消息"
    }
}

struct DemoContact: Identifiable, Codable {
    var id = UUID()
    var name: String
    var initials: String
}

struct DemoMoment: Identifiable, Codable {
    var id = UUID()
    var author: String
    var text: String
    var imageData: Data?
    var date = Date()
}

struct SavedData: Codable {
    var chats: [DemoChat]
    var moments: [DemoMoment]
}

// MARK: - Storage

@MainActor
final class ChatStore: ObservableObject {
    @Published var chats: [DemoChat] = []
    @Published var moments: [DemoMoment] = []

    let contacts: [DemoContact] = [
        DemoContact(name: "张小明", initials: "张"),
        DemoContact(name: "李小红", initials: "李"),
        DemoContact(name: "王先生", initials: "王"),
        DemoContact(name: "演示联系人", initials: "演"),
        DemoContact(name: "文件传输助手", initials: "文"),
        DemoContact(name: "产品交流群", initials: "群")
    ]

    private var storageURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("wechat_demo_data.json")
    }

    init() {
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: storageURL),
           let saved = try? JSONDecoder().decode(
                SavedData.self,
                from: data
           ) {
            chats = saved.chats
            moments = saved.moments
            return
        }

        chats = [
            DemoChat(
                name: "文件传输助手",
                messages: [
                    DemoMessage(
                        text: "欢迎使用微信风格演示应用",
                        incoming: true
                    )
                ]
            ),
            DemoChat(
                name: "演示联系人",
                messages: [
                    DemoMessage(
                        text: "你好，欢迎使用！",
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

        moments = [
            DemoMoment(
                author: "演示联系人",
                text: "欢迎来到我的朋友圈！",
                imageData: nil
            ),
            DemoMoment(
                author: "张小明",
                text: "美好的一天，从这里开始。",
                imageData: nil
            )
        ]

        save()
    }

    private func save() {
        let data = SavedData(
            chats: chats,
            moments: moments
        )

        guard let encoded = try? JSONEncoder().encode(data) else {
            return
        }

        try? encoded.write(to: storageURL, options: .atomic)
    }

    func chatID(for contact: DemoContact) -> UUID {
        if let existing = chats.first(where: {
            $0.name == contact.name
        }) {
            return existing.id
        }

        let newChat = DemoChat(
            name: contact.name,
            messages: []
        )

        chats.insert(newChat, at: 0)
        save()
        return newChat.id
    }

    func addChat() {
        let number = chats.count + 1

        chats.insert(
            DemoChat(
                name: "新建会话 \(number)",
                messages: []
            ),
            at: 0
        )

        save()
    }

    func sendText(_ text: String, to chatID: UUID) {
        guard let index = chats.firstIndex(where: {
            $0.id == chatID
        }) else {
            return
        }

        chats[index].messages.append(
            DemoMessage(
                text: text,
                incoming: false
            )
        )

        chats[index].updatedAt = Date()
        save()
    }

    func sendImage(_ data: Data, to chatID: UUID) {
        guard let index = chats.firstIndex(where: {
            $0.id == chatID
        }) else {
            return
        }

        chats[index].messages.append(
            DemoMessage(
                text: "",
                incoming: false,
                imageData: data
            )
        )

        chats[index].updatedAt = Date()
        save()
    }

    func publishMoment(text: String, imageData: Data?) {
        moments.insert(
            DemoMoment(
                author: "我",
                text: text,
                imageData: imageData
            ),
            at: 0
        )

        save()
    }
}

// MARK: - Main App

struct MainView: View {
    @StateObject private var store = ChatStore()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            ChatListView(store: store)
                .tabItem {
                    Label("微信", systemImage: "message")
                }
                .tag(0)

            ContactsView(store: store)
                .tabItem {
                    Label("通讯录", systemImage: "person.2")
                }
                .tag(1)

            MomentsView(store: store)
                .tabItem {
                    Label("发现", systemImage: "safari")
                }
                .tag(2)

            ProfileView()
                .tabItem {
                    Label("我", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .tint(.green)
    }
}

// MARK: - Avatar

struct DemoAvatar: View {
    let name: String
    var size: CGFloat = 52

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.green.opacity(0.16))
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.green)
            }
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
                        HStack(spacing: 12) {
                            DemoAvatar(name: chat.name)

                            VStack(alignment: .leading, spacing: 6) {
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
            }
            .listStyle(.plain)
            .navigationTitle("微信")
            .searchable(text: $searchText, prompt: "搜索")
            .navigationDestination(for: UUID.self) { id in
                ChatDetailView(store: store, chatID: id)
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

// MARK: - Chat Detail

struct ChatDetailView: View {
    @ObservedObject var store: ChatStore
    let chatID: UUID

    @State private var draft = ""
    @State private var selectedPhoto: PhotosPickerItem?

    private var chat: DemoChat? {
        store.chats.first { $0.id == chatID }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let chat = chat {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 15) {
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

                inputBar
            } else {
                ContentUnavailableView(
                    "会话不存在",
                    systemImage: "message"
                )
            }
        }
        .navigationTitle(chat?.name ?? "聊天")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhoto) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(
                    type: Data.self
                ) else {
                    return
                }

                await MainActor.run {
                    store.sendImage(data, to: chatID)
                    selectedPhoto = nil
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 9) {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(.green)
            }

            TextField("输入消息...", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)

            Button("发送") {
                let text = draft.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                guard !text.isEmpty else { return }

                store.sendText(text, to: chatID)
                draft = ""
            }
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                draft.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty ? Color.gray : Color.green
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .disabled(
                draft.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
    let message: DemoMessage

    var body: some View {
        HStack {
            if message.incoming {
                bubble
                Spacer(minLength: 45)
            } else {
                Spacer(minLength: 45)
                bubble
            }
        }
    }

    private var bubble: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let data = message.imageData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 210, maxHeight: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(
                        message.incoming ? Color.primary : Color.white
                    )
            }

            Text(message.time, style: .time)
                .font(.system(size: 10))
                .foregroundStyle(
                    message.incoming
                    ? Color.secondary
                    : Color.white.opacity(0.75)
                )
        }
        .padding(10)
        .background(
            message.incoming
            ? Color(uiColor: .secondarySystemBackground)
            : Color.green
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Contacts

struct ContactsView: View {
    @ObservedObject var store: ChatStore
    @State private var searchText = ""

    private var filteredContacts: [DemoContact] {
        if searchText.isEmpty {
            return store.contacts
        }

        return store.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredContacts) { contact in
                    NavigationLink {
                        ChatDetailView(
                            store: store,
                            chatID: store.chatID(for: contact)
                        )
                    } label: {
                        HStack(spacing: 12) {
                            DemoAvatar(name: contact.name)

                            Text(contact.name)
                                .font(.system(size: 16))
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("通讯录")
            .searchable(text: $searchText, prompt: "搜索联系人")
        }
    }
}

// MARK: - Moments

struct MomentsView: View {
    @ObservedObject var store: ChatStore

    @State private var draft = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImageData: Data?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField(
                            "分享你的生活...",
                            text: $draft,
                            axis: .vertical
                        )
                        .lineLimit(2...5)

                        if let data = selectedImageData,
                           let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 190)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        HStack {
                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images
                            ) {
                                Label(
                                    "选择图片",
                                    systemImage: "photo"
                                )
                                .foregroundStyle(.green)
                            }

                            Spacer()

                            Button("发布") {
                                let text = draft.trimmingCharacters(
                                    in: .whitespacesAndNewlines
                                )

                                guard !text.isEmpty || selectedImageData != nil else {
                                    return
                                }

                                store.publishMoment(
                                    text: text,
                                    imageData: selectedImageData
                                )

                                draft = ""
                                selectedImageData = nil
                                selectedPhoto = nil
                            }
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 5)
                } header: {
                    Text("发布动态")
                }

                Section("朋友圈") {
                    ForEach(store.moments) { moment in
                        MomentRowView(moment: moment)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("发现")
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    guard let data = try? await item?.loadTransferable(
                        type: Data.self
                    ) else {
                        return
                    }

                    await MainActor.run {
                        selectedImageData = data
                    }
                }
            }
        }
    }
}

// MARK: - Moment Row

struct MomentRowView: View {
    let moment: DemoMoment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DemoAvatar(name: moment.author, size: 46)

            VStack(alignment: .leading, spacing: 9) {
                Text(moment.author)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.blue)

                if !moment.text.isEmpty {
                    Text(moment.text)
                        .font(.system(size: 15))
                }

                if let data = moment.imageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 230, maxHeight: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Text(moment.date, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text(moment.date, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Profile

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 68, height: 68)
                            .overlay {
                                Image(systemName: "person.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.green)
                            }

                        VStack(alignment: .leading, spacing: 7) {
                            Text("我的账号")
                                .font(.system(size: 20, weight: .semibold))

                            Text("微信号：Demo_2026")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }

                Section {
                    Label("服务", systemImage: "square.grid.2x2")
                    Label("收藏", systemImage: "star")
                    Label("朋友圈相册", systemImage: "photo")
                    Label("卡包", systemImage: "creditcard")
                }

                Section {
                    Label("设置", systemImage: "gearshape")
                    Label("关于演示应用", systemImage: "info.circle")
                }
            }
            .navigationTitle("我")
        }
    }
}
