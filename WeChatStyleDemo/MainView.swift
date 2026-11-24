
import SwiftUI
import PhotosUI
import UIKit
import Combine

// MARK: - App

@main
struct WeChatStyleDemoApp: App {
    @StateObject private var store = ChatStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Models

struct DemoMessage: Identifiable, Codable {
    var id = UUID()
    var text: String
    var incoming: Bool
    var time = Date()
    var imagePath: String? = nil
}

struct DemoChat: Identifiable, Codable {
    var id = UUID()
    var name: String
    var avatar: String
    var messages: [DemoMessage] = []
    var updatedAt = Date()

    var lastMessage: String {
        guard let message = messages.last else {
            return "暂无消息"
        }
        return message.imagePath == nil ? message.text : "[图片]"
    }
}

struct DemoMoment: Identifiable, Codable {
    var id = UUID()
    var text: String
    var imagePath: String?
    var time = Date()
}

struct SavedData: Codable {
    var chats: [DemoChat]
    var moments: [DemoMoment]
}

// MARK: - Data Store

@MainActor
final class ChatStore: ObservableObject {
    @Published var chats: [DemoChat] = []
    @Published var moments: [DemoMoment] = []

    private let fileName = "wechat_demo_data.json"

    private var dataURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(fileName)
    }

    private var mediaDirectory: URL {
        let url = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Media")

        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )

        return url
    }

    init() {
        load()

        if chats.isEmpty {
            chats = [
                DemoChat(
                    name: "文件传输助手",
                    avatar: "📁"
                ),
                DemoChat(
                    name: "演示联系人",
                    avatar: "😊"
                )
            ]
            save()
        }
    }

    func load() {
        guard
            let data = try? Data(contentsOf: dataURL),
            let saved = try? JSONDecoder().decode(
                SavedData.self,
                from: data
            )
        else {
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
        let name = UUID().uuidString + ".jpg"
        let url = mediaDirectory.appendingPathComponent(name)

        guard let image = UIImage(data: data),
              let compressed = image.jpegData(compressionQuality: 0.85)
        else {
            return nil
        }

        do {
            try compressed.write(to: url)
            return name
        } catch {
            return nil
        }
    }

    func imageURL(_ name: String) -> URL {
        mediaDirectory.appendingPathComponent(name)
    }

    func addContact(_ name: String) {
        let value = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !value.isEmpty else { return }

        guard !chats.contains(where: { $0.name == value }) else {
            return
        }

        chats.insert(
            DemoChat(name: value, avatar: "👤"),
            at: 0
        )

        save()
    }

    func sendText(_ text: String, to id: UUID) {
        let value = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !value.isEmpty,
              let index = chats.firstIndex(where: { $0.id == id })
        else {
            return
        }

        chats[index].messages.append(
            DemoMessage(
                text: value,
                incoming: false
            )
        )

        chats[index].updatedAt = Date()
        moveChatToTop(id)
        save()
    }

    func sendImage(_ data: Data, to id: UUID) {
        guard let path = saveImage(data),
              let index = chats.firstIndex(where: { $0.id == id })
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
        moveChatToTop(id)
        save()
    }

    func publishMoment(_ text: String, imageData: Data?) {
        let path = imageData.flatMap { saveImage($0) }

        let value = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !value.isEmpty || path != nil else {
            return
        }

        moments.insert(
            DemoMoment(
                text: value,
                imagePath: path
            ),
            at: 0
        )

        save()
    }

    func moveChatToTop(_ id: UUID) {
        guard let index = chats.firstIndex(where: { $0.id == id }) else {
            return
        }

        let chat = chats.remove(at: index)
        chats.insert(chat, at: 0)
    }

    func deleteChat(_ id: UUID) {
        chats.removeAll { $0.id == id }
        save()
    }
}

// MARK: - Liquid Glass Style

extension View {
    func liquidGlass<S: Shape>(
        in shape: S
    ) -> some View {
        modifier(LiquidGlassModifier(shape: shape))
    }
}

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(
                .regular,
                in: shape
            )
        } else {
            content.background(
                .ultraThinMaterial,
                in: shape
            )
            .overlay {
                shape.stroke(
                    Color.white.opacity(0.5),
                    lineWidth: 1
                )
            }
        }
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Color(
                red: 0.91,
                green: 0.95,
                blue: 0.99
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.85),
                    Color.blue.opacity(0.08),
                    Color.purple.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Main Navigation

enum MainTab: String, CaseIterable {
    case wechat = "微信"
    case contacts = "通讯录"
    case discover = "发现"
    case me = "我"

    var icon: String {
        switch self {
        case .wechat: return "message.fill"
        case .contacts: return "person.2.fill"
        case .discover: return "safari.fill"
        case .me: return "person.crop.circle.fill"
        }
    }
}

struct MainView: View {
    @EnvironmentObject var store: ChatStore

    @State private var selectedTab: MainTab = .wechat
    @State private var selectedChatID: UUID?
    @State private var searchText = ""
    @State private var showAddContact = false
    @State private var newContactName = ""

    var filteredChats: [DemoChat] {
        if searchText.isEmpty {
            return store.chats
        }

        return store.chats.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case .wechat:
                        chatList

                    case .contacts:
                        contactsPage

                    case .discover:
                        MomentsView()

                    case .me:
                        profilePage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
            }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedChatID != nil },
                set: { value in
                    if !value {
                        selectedChatID = nil
                    }
                }
            )
        ) {
            if let id = selectedChatID {
                ChatDetailView(chatID: id)
                    .environmentObject(store)
            }
        }
        .alert("添加联系人", isPresented: $showAddContact) {
            TextField("输入联系人名称", text: $newContactName)

            Button("取消", role: .cancel) {
                newContactName = ""
            }

            Button("添加") {
                store.addContact(newContactName)
                newContactName = ""
            }
        }
    }

    // MARK: Chat List

    private var chatList: some View {
        VStack(spacing: 14) {
            header(
                title: "微信",
                action: {
                    showAddContact = true
                }
            )

            searchBar

            if filteredChats.isEmpty {
                Spacer()
                Image(systemName: "message")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)

                Text("没有找到聊天")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredChats) { chat in
                            Button {
                                selectedChatID = chat.id
                            } label: {
                                ChatRow(chat: chat)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(
                                    "删除聊天",
                                    role: .destructive
                                ) {
                                    store.deleteChat(chat.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: Contacts

    private var contactsPage: some View {
        VStack(spacing: 14) {
            header(
                title: "通讯录",
                action: {
                    showAddContact = true
                }
            )

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(store.chats) { chat in
                        Button {
                            selectedChatID = chat.id
                        } label: {
                            HStack(spacing: 14) {
                                AvatarView(avatar: chat.avatar)

                                Text(chat.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .liquidGlass(
                                in: RoundedRectangle(cornerRadius: 20)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: Profile

    private var profilePage: some View {
        VStack(spacing: 22) {
            header(title: "个人中心")

            HStack(spacing: 16) {
                AvatarView(
                    avatar: "😊",
                    size: 72
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text("微信演示用户")
                        .font(.title2.bold())

                    Text("微信号：WeChatDemo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 25)
            )
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                profileItem("收藏", icon: "star.fill")
                Divider().padding(.leading, 55)
                profileItem("朋友圈", icon: "photo.fill")
                Divider().padding(.leading, 55)
                profileItem("设置", icon: "gearshape.fill")
                Divider().padding(.leading, 55)
                profileItem("关于", icon: "info.circle.fill")
            }
            .padding(.horizontal, 16)
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 24)
            )

            Spacer()
        }
    }

    private func profileItem(
        _ title: String,
        icon: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 25)

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    // MARK: Common Header

    private func header(
        title: String,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 27, weight: .bold))

            Spacer()

            if let action {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .liquidGlass(
                            in: Circle()
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索聊天", text: $searchText)
                .textInputAutocapitalization(.never)
        }
        .padding(13)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 16)
        )
        .padding(.horizontal, 16)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))

                        Text(tab.rawValue)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(
                        selectedTab == tab
                        ? Color.green
                        : Color.secondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 27)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 5)
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let chat: DemoChat

    var body: some View {
        HStack(spacing: 13) {
            AvatarView(avatar: chat.avatar)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(chat.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(chat.updatedAt, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(chat.lastMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(13)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 21)
        )
    }
}

// MARK: - Chat Detail

struct ChatDetailView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    let chatID: UUID

    @State private var messageText = ""
    @State private var selectedPhoto: PhotosPickerItem?

    private var chat: DemoChat? {
        store.chats.first(where: { $0.id == chatID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    messageList
                    inputBar
                }
            }
            .navigationTitle(chat?.name ?? "聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }

            Task {
                if let data = try? await item.loadTransferable(
                    type: Data.self
                ) {
                    await MainActor.run {
                        store.sendImage(data, to: chatID)
                    }
                }

                selectedPhoto = nil
            }
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if let chat {
                        ForEach(chat.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(16)
            }
            .onChange(
                of: chat?.messages.count ?? 0
            ) { _, _ in
                guard let last = chat?.messages.last else {
                    return
                }

                withAnimation {
                    proxy.scrollTo(
                        last.id,
                        anchor: .bottom
                    )
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 27))
                    .foregroundStyle(.primary)
            }

            TextField("发送消息...", text: $messageText)
                .padding(12)
                .liquidGlass(
                    in: RoundedRectangle(cornerRadius: 18)
                )

            Button {
                store.sendText(
                    messageText,
                    to: chatID
                )
                messageText = ""
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Color.green,
                        in: Circle()
                    )
            }
            .disabled(
                messageText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        }
        .padding(12)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 25)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DemoMessage

    var body: some View {
        HStack {
            if !message.incoming {
                Spacer(minLength: 45)
            }

            VStack(alignment: .leading, spacing: 5) {
                if let path = message.imagePath {
                    if let image = UIImage(
                        contentsOfFile: mediaPath(path)
                    ) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 210)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 14)
                            )
                    }
                } else {
                    Text(message.text)
                        .foregroundStyle(.primary)
                        .padding(12)
                }
            }
            .liquidGlass(
                in: RoundedRectangle(cornerRadius: 17)
            )

            if message.incoming {
                Spacer(minLength: 45)
            }
        }
    }

    private func mediaPath(_ name: String) -> String {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("Media")
        .appendingPathComponent(name)
        .path
    }
}

// MARK: - Moments

struct MomentsView: View {
    @EnvironmentObject var store: ChatStore

    @State private var showPublish = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("发现")
                    .font(.system(size: 27, weight: .bold))

                Spacer()

                Button {
                    showPublish = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .liquidGlass(in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(spacing: 14) {
                    if store.moments.isEmpty {
                        Text("还没有朋友圈内容")
                            .foregroundStyle(.secondary)
                            .padding(.top, 60)
                    }

                    ForEach(store.moments) { moment in
                        MomentRow(moment: moment)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showPublish) {
            PublishMomentView()
                .environmentObject(store)
        }
    }
}

struct MomentRow: View {
    let moment: DemoMoment

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AvatarView(avatar: "😊", size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("微信演示用户")
                        .font(.system(size: 15, weight: .semibold))

                    Text(moment.time, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !moment.text.isEmpty {
                Text(moment.text)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
            }

            if let path = moment.imagePath {
                let url = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                )[0]
                .appendingPathComponent("Media")
                .appendingPathComponent(path)

                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(
                            RoundedRectangle(cornerRadius: 15)
                        )
                }
            }
        }
        .padding(15)
        .liquidGlass(
            in: RoundedRectangle(cornerRadius: 23)
        )
    }
}

// MARK: - Publish Moment

struct PublishMomentView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 18) {
                    TextEditor(text: $text)
                        .frame(minHeight: 150)
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .liquidGlass(
                            in: RoundedRectangle(cornerRadius: 20)
                        )

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        Label(
                            "选择朋友圈图片",
                            systemImage: "photo"
                        )
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .liquidGlass(
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                    }

                    if let imageData,
                       let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 16)
                            )
                    }

                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("发表朋友圈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("发表") {
                        store.publishMoment(
                            text,
                            imageData: imageData
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
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

// MARK: - Avatar

struct AvatarView: View {
    let avatar: String
    var size: CGFloat = 52

    var body: some View {
        Text(avatar)
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(
                Color.white.opacity(0.65),
                in: RoundedRectangle(cornerRadius: size * 0.28)
            )
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28)
                    .stroke(
                        Color.white.opacity(0.7),
                        lineWidth: 1
                    )
            }
    }
}
