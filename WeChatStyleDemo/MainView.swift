
import SwiftUI
import PhotosUI
import UIKit
import Combine

@main
struct WeChatStyleDemoApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
        }
    }
}

// MARK: - Data Models

struct DemoMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var incoming: Bool
    var time = Date()
    var imagePath: String?
}

struct DemoChat: Identifiable, Codable {
    var id = UUID()
    var name: String
    var avatar: String
    var messages: [DemoMessage] = []
    var updatedAt = Date()

    var lastMessage: String {
        guard let message = messages.last else {
            return "开始聊天"
        }
        return message.imagePath != nil ? "[图片]" : message.text
    }
}

struct DemoMoment: Identifiable, Codable {
    var id = UUID()
    var name: String
    var avatar: String
    var text: String
    var time = Date()
    var imagePath: String?
}

struct SavedData: Codable {
    var chats: [DemoChat]
    var moments: [DemoMoment]
}

// MARK: - Local Data Store

@MainActor
final class ChatStore: ObservableObject {
    @Published var chats: [DemoChat] = []
    @Published var moments: [DemoMoment] = []

    private let fileName = "wechat_demo_data.json"

    private var documentsURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    private var dataURL: URL {
        documentsURL.appendingPathComponent(fileName)
    }

    private var mediaURL: URL {
        documentsURL.appendingPathComponent(
            "Media",
            isDirectory: true
        )
    }

    init() {
        createMediaFolder()
        load()
    }

    private func createMediaFolder() {
        try? FileManager.default.createDirectory(
            at: mediaURL,
            withIntermediateDirectories: true
        )
    }

    func load() {
        guard
            let data = try? Data(contentsOf: dataURL),
            let saved = try? JSONDecoder().decode(
                SavedData.self,
                from: data
            )
        else {
            chats = [
                DemoChat(
                    name: "文件传输助手",
                    avatar: "📁",
                    messages: [
                        DemoMessage(
                            text: "欢迎使用微信风格演示应用！",
                            incoming: true
                        )
                    ]
                ),
                DemoChat(
                    name: "演示联系人",
                    avatar: "😊",
                    messages: [
                        DemoMessage(
                            text: "你好，欢迎体验 3.1 版本。",
                            incoming: true
                        )
                    ]
                )
            ]
            moments = []
            save()
            return
        }

        chats = saved.chats
        moments = saved.moments
    }

    func save() {
        let saved = SavedData(
            chats: chats,
            moments: moments
        )

        guard let data = try? JSONEncoder().encode(saved) else {
            return
        }

        try? data.write(to: dataURL, options: .atomic)
    }

    func saveImage(_ data: Data) -> String? {
        createMediaFolder()

        guard
            let image = UIImage(data: data),
            let compressed = image.jpegData(
                compressionQuality: 0.85
            )
        else {
            return nil
        }

        let name = UUID().uuidString + ".jpg"
        let url = mediaURL.appendingPathComponent(name)

        do {
            try compressed.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func imageURL(for name: String?) -> URL? {
        guard let name else { return nil }
        return mediaURL.appendingPathComponent(name)
    }

    func addContact(name: String) {
        let cleanName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanName.isEmpty else { return }
        guard !chats.contains(where: { $0.name == cleanName }) else {
            return
        }

        chats.insert(
            DemoChat(name: cleanName, avatar: "🙂"),
            at: 0
        )

        save()
    }

    func sendText(_ text: String, to chatID: UUID) {
        let cleanText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard
            !cleanText.isEmpty,
            let index = chats.firstIndex(where: { $0.id == chatID })
        else {
            return
        }

        chats[index].messages.append(
            DemoMessage(
                text: cleanText,
                incoming: false
            )
        )

        chats[index].updatedAt = Date()
        moveChatToTop(chatID)
        save()
    }

    func sendImage(_ data: Data, to chatID: UUID) {
        guard
            let path = saveImage(data),
            let index = chats.firstIndex(where: { $0.id == chatID })
        else {
            return
        }

        chats[index].messages.append(
            DemoMessage(
                text: "",
                incoming: false,
                imagePath: path
            )
        )

        chats[index].updatedAt = Date()
        moveChatToTop(chatID)
        save()
    }

    private func moveChatToTop(_ id: UUID) {
        guard let index = chats.firstIndex(
            where: { $0.id == id }
        ) else {
            return
        }

        let chat = chats.remove(at: index)
        chats.insert(chat, at: 0)
    }

    func publishMoment(text: String, imageData: Data?) {
        let cleanText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanText.isEmpty || imageData != nil else {
            return
        }

        let path = imageData.flatMap { saveImage($0) }

        moments.insert(
            DemoMoment(
                name: "我",
                avatar: "🙂",
                text: cleanText,
                imagePath: path
            ),
            at: 0
        )

        save()
    }
}

// MARK: - Main Navigation

struct MainView: View {
    @EnvironmentObject private var store: ChatStore

    @State private var selectedTab = 0
    @State private var selectedChatID: UUID?
    @State private var searchText = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            chatList
                .tabItem {
                    Label("微信", systemImage: "message.fill")
                }
                .tag(0)

            contactsPage
                .tabItem {
                    Label(
                        "通讯录",
                        systemImage: "person.crop.rectangle"
                    )
                }
                .tag(1)

            discoverPage
                .tabItem {
                    Label("发现", systemImage: "safari")
                }
                .tag(2)

            profilePage
                .tabItem {
                    Label(
                        "我",
                        systemImage: "person.crop.circle"
                    )
                }
                .tag(3)
        }
        .tint(Color(
            red: 0.07,
            green: 0.72,
            blue: 0.35
        ))
        .sheet(
            isPresented: Binding(
                get: { selectedChatID != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedChatID = nil
                    }
                }
            )
        ) {
            if let chatID = selectedChatID {
                ChatDetailView(chatID: chatID)
                    .environmentObject(store)
            }
        }
    }

    private var chatList: some View {
        NavigationStack {
            List {
                ForEach(filteredChats) { chat in
                    Button {
                        selectedChatID = chat.id
                    } label: {
                        ChatRow(chat: chat)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteChats)
            }
            .listStyle(.plain)
            .navigationTitle("微信")
            .searchable(
                text: $searchText,
                prompt: "搜索"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(
                            "添加联系人",
                            systemImage: "person.badge.plus"
                        ) {
                            selectedTab = 1
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.title3)
                    }
                }
            }
        }
    }

    private var filteredChats: [DemoChat] {
        guard !searchText.isEmpty else {
            return store.chats
        }

        return store.chats.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func deleteChats(at offsets: IndexSet) {
        let ids = offsets.map { filteredChats[$0].id }

        store.chats.removeAll {
            ids.contains($0.id)
        }

        store.save()
    }

    private var contactsPage: some View {
        NavigationStack {
            List {
                Section {
                    Label(
                        "新的朋友",
                        systemImage: "person.badge.plus"
                    )
                    Label("群聊", systemImage: "person.2")
                    Label("标签", systemImage: "tag")
                    Label("公众号", systemImage: "building.2")
                }

                Section("联系人") {
                    ForEach(store.chats) { chat in
                        Button {
                            selectedChatID = chat.id
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    value: chat.avatar,
                                    size: 42
                                )

                                Text(chat.name)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("通讯录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AddContactButton()
                }
            }
        }
    }

    private var discoverPage: some View {
        NavigationStack {
            List {
                NavigationLink {
                    MomentsView()
                } label: {
                    Label(
                        "朋友圈",
                        systemImage: "photo.on.rectangle.angled"
                    )
                }

                Label(
                    "视频号",
                    systemImage: "play.rectangle"
                )
                Label("扫一扫", systemImage: "qrcode.viewfinder")
                Label("摇一摇", systemImage: "iphone.gen3.radiowaves.left.and.right")
                Label("看一看", systemImage: "safari")
                Label("搜一搜", systemImage: "magnifyingglass")
            }
            .navigationTitle("发现")
        }
    }

    private var profilePage: some View {
        NavigationStack {
            List {
                HStack(spacing: 16) {
                    AvatarView(value: "🙂", size: 68)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("我的微信")
                            .font(.title2)
                            .bold()

                        Text("微信号：demo_310")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)

                Section {
                    Label("服务", systemImage: "creditcard")
                    Label("收藏", systemImage: "star")
                    Label("朋友圈", systemImage: "photo")
                    Label("卡包", systemImage: "wallet.pass")
                }

                Section {
                    Label("设置", systemImage: "gearshape")
                }
            }
            .navigationTitle("我")
        }
    }
}

// MARK: - Chat List Row

struct ChatRow: View {
    let chat: DemoChat

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                value: chat.avatar,
                size: 52
            )

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(chat.name)
                        .font(.system(
                            size: 16,
                            weight: .medium
                        ))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(chat.updatedAt, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.vertical, 5)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Chat Detail

struct ChatDetailView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    let chatID: UUID

    @State private var messageText = ""
    @State private var selectedPhoto: PhotosPickerItem?

    private var chat: DemoChat? {
        store.chats.first {
            $0.id == chatID
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let chat {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 14) {
                                ForEach(chat.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .background(
                            Color(uiColor: .systemGroupedBackground)
                        )
                        .onChange(of: chat.messages.count) {
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
                } else {
                    ContentUnavailableView(
                        "聊天不存在",
                        systemImage: "message"
                    )
                }
            }
            .navigationTitle(chat?.name ?? "聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }

            Task {
                if let data = try? await item.loadTransferable(
                    type: Data.self
                ) {
                    store.sendImage(data, to: chatID)
                }

                selectedPhoto = nil
            }
        }
    }

    private var messageInput: some View {
        HStack(alignment: .bottom, spacing: 10) {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 27))
                    .foregroundStyle(.primary)
            }

            TextField(
                "输入消息...",
                text: $messageText,
                axis: .vertical
            )
            .lineLimit(1...4)
            .padding(10)
            .background(
                Color(uiColor: .secondarySystemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button("发送") {
                store.sendText(
                    messageText,
                    to: chatID
                )
                messageText = ""
            }
            .fontWeight(.semibold)
            .disabled(
                messageText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 9)
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    @EnvironmentObject private var store: ChatStore

    let message: DemoMessage

    var body: some View {
        HStack {
            if !message.incoming {
                Spacer(minLength: 50)
            }

            VStack(alignment: .leading, spacing: 5) {
                if let url = store.imageURL(
                    for: message.imagePath
                ),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: 210,
                            maxHeight: 240
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            message.incoming
                            ? Color(uiColor: .secondarySystemBackground)
                            : Color(
                                red: 0.60,
                                green: 0.91,
                                blue: 0.57
                            )
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                }

                Text(message.time, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if message.incoming {
                Spacer(minLength: 50)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Moments

struct MomentsView: View {
    @EnvironmentObject private var store: ChatStore

    var body: some View {
        List {
            ForEach(store.moments) { moment in
                MomentRow(moment: moment)
            }
        }
        .listStyle(.plain)
        .navigationTitle("朋友圈")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PublishMomentView()
                } label: {
                    Image(systemName: "camera")
                        .font(.title3)
                }
            }
        }
    }
}

struct MomentRow: View {
    @EnvironmentObject private var store: ChatStore

    let moment: DemoMoment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(
                value: moment.avatar,
                size: 44
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(moment.name)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)

                if !moment.text.isEmpty {
                    Text(moment.text)
                }

                if let url = store.imageURL(
                    for: moment.imagePath
                ),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: 230,
                            maxHeight: 240
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 8)
                        )
                }

                Text(moment.time, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

struct PublishMomentView: View {
    @EnvironmentObject private var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        Form {
            Section("分享内容") {
                TextEditor(text: $text)
                    .frame(minHeight: 150)
            }

            Section("添加图片") {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label(
                        "从相册选择图片",
                        systemImage: "photo"
                    )
                }

                if let imageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                }
            }
        }
        .navigationTitle("发表朋友圈")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("发表") {
                    store.publishMoment(
                        text: text,
                        imageData: imageData
                    )
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(
                    text.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty && imageData == nil
                )
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }

            Task {
                imageData = try? await item.loadTransferable(
                    type: Data.self
                )
            }
        }
    }
}

// MARK: - Add Contact

struct AddContactButton: View {
    @EnvironmentObject private var store: ChatStore

    @State private var showingAlert = false
    @State private var contactName = ""

    var body: some View {
        Button {
            contactName = ""
            showingAlert = true
        } label: {
            Image(systemName: "person.badge.plus")
                .font(.title3)
        }
        .alert(
            "添加联系人",
            isPresented: $showingAlert
        ) {
            TextField(
                "输入联系人名称",
                text: $contactName
            )

            Button("取消", role: .cancel) {}

            Button("添加") {
                store.addContact(name: contactName)
            }
        } message: {
            Text("添加后会出现在通讯录和聊天列表中。")
        }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let value: String
    let size: CGFloat

    var body: some View {
        Text(value)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(
                Color(uiColor: .secondarySystemBackground)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: size * 0.22)
            )
    }
}
