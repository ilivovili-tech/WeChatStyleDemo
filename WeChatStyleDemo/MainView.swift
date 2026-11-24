
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
            return "暂无消息"
        }

        if let path = message.imagePath, !path.isEmpty {
            return "图片"
        }

        return message.text
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

    private var documentsURL: URL {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
    }

    private var dataURL: URL {
        documentsURL.appendingPathComponent(fileName)
    }

    private var mediaDirectory: URL {
        documentsURL.appendingPathComponent("Media")
    }

    init() {
        createMediaDirectory()
        loadData()

        if chats.isEmpty {
            createInitialData()
        }
    }

    private func createMediaDirectory() {
        try? FileManager.default.createDirectory(
            at: mediaDirectory,
            withIntermediateDirectories: true
        )
    }

    private func createInitialData() {
        chats = [
            DemoChat(
                name: "文件传输助手",
                avatar: "folder.fill",
                messages: [
                    DemoMessage(
                        text: "欢迎使用微信风格演示应用",
                        incoming: true
                    )
                ]
            ),
            DemoChat(
                name: "ChatGPT",
                avatar: "sparkles",
                messages: [
                    DemoMessage(
                        text: "你好！有什么可以帮忙的？",
                        incoming: true
                    )
                ]
            )
        ]

        saveData()
    }

    func loadData() {
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

    func saveData() {
        let saved = SavedData(
            chats: chats,
            moments: moments
        )

        guard let data = try? JSONEncoder().encode(saved) else {
            return
        }

        try? data.write(
            to: dataURL,
            options: .atomic
        )
    }

    func saveImage(_ image: UIImage) -> String? {
        createMediaDirectory()

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            return nil
        }

        let name = UUID().uuidString + ".jpg"
        let url = mediaDirectory.appendingPathComponent(name)

        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func imageURL(for path: String?) -> URL? {
        guard let path, !path.isEmpty else {
            return nil
        }

        return mediaDirectory.appendingPathComponent(path)
    }

    func addContact(name: String) {
        let cleanName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanName.isEmpty else {
            return
        }

        guard !chats.contains(where: {
            $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame
        }) else {
            return
        }

        chats.insert(
            DemoChat(
                name: cleanName,
                avatar: "person.fill"
            ),
            at: 0
        )

        saveData()
    }

    func sendText(_ text: String, to chatID: UUID) {
        guard let index = chats.firstIndex(where: {
            $0.id == chatID
        }) else {
            return
        }

        let cleanText = text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanText.isEmpty else {
            return
        }

        let message = DemoMessage(
            text: cleanText,
            incoming: false
        )

        chats[index].messages.append(message)
        chats[index].updatedAt = Date()

        moveChatToTop(chatID)
        saveData()
    }

    func sendImage(_ image: UIImage, to chatID: UUID) {
        guard let path = saveImage(image) else {
            return
        }

        guard let index = chats.firstIndex(where: {
            $0.id == chatID
        }) else {
            return
        }

        let message = DemoMessage(
            text: "",
            incoming: false,
            imagePath: path
        )

        chats[index].messages.append(message)
        chats[index].updatedAt = Date()

        moveChatToTop(chatID)
        saveData()
    }

    func publishMoment(text: String, image: UIImage?) {
        let path = image.flatMap { saveImage($0) }

        let moment = DemoMoment(
            text: text,
            imagePath: path
        )

        moments.insert(moment, at: 0)
        saveData()
    }

    func moveChatToTop(_ id: UUID) {
        guard let index = chats.firstIndex(where: {
            $0.id == id
        }) else {
            return
        }

        let chat = chats.remove(at: index)
        chats.insert(chat, at: 0)
    }

    func deleteChat(_ id: UUID) {
        chats.removeAll {
            $0.id == id
        }

        saveData()
    }
}

// MARK: - Liquid Glass

extension View {
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        modifier(LiquidGlassModifier(shape: shape))
    }
}

struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        Color.white.opacity(0.55),
                        lineWidth: 1
                    )
                }
        }
    }
}

// MARK: - Background

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.97, blue: 0.98),
                Color(red: 0.96, green: 0.97, blue: 0.94),
                Color(red: 0.94, green: 0.96, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Tabs

enum MainTab: String, CaseIterable, Identifiable {
    case wechat = "微信"
    case contacts = "通讯录"
    case discover = "发现"
    case me = "我"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .wechat:
            return "message.fill"
        case .contacts:
            return "person.2.fill"
        case .discover:
            return "safari.fill"
        case .me:
            return "person.crop.circle.fill"
        }
    }
}

// MARK: - Main View

struct MainView: View {

    @EnvironmentObject var store: ChatStore

    @State private var selectedTab: MainTab = .wechat
    @State private var selectedChatID: UUID?
    @State private var searchText = ""

    @State private var showAddContact = false
    @State private var newContactName = ""

    @Namespace private var tabAnimation

    private var filteredChats: [DemoChat] {
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
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            handlePageSwipe(value)
                        }
                )

                bottomBar
            }
        }
        .sheet(item: $selectedChatID) { id in
            ChatDetailView(chatID: id)
                .environmentObject(store)
        }
        .alert("添加联系人", isPresented: $showAddContact) {
            TextField("请输入联系人名称", text: $newContactName)

            Button("取消", role: .cancel) {
                newContactName = ""
            }

            Button("添加") {
                store.addContact(name: newContactName)
                newContactName = ""
            }
        } message: {
            Text("添加一个新的本地联系人")
        }
    }

    // MARK: Chat List

    private var chatList: some View {
        VStack(spacing: 0) {
            header(
                title: "微信",
                trailingIcon: "plus"
            ) {
                showAddContact = true
            }

            searchBar

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredChats) { chat in
                        Button {
                            selectedChatID = chat.id
                        } label: {
                            ChatRow(chat: chat)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteChat(chat.id)
                            } label: {
                                Label("删除聊天", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Contacts

    private var contactsPage: some View {
        VStack(spacing: 0) {
            header(
                title: "通讯录",
                trailingIcon: "plus"
            ) {
                showAddContact = true
            }

            searchBar

            ScrollView {
                LazyVStack(spacing: 10) {
                    Button {
                        showAddContact = true
                    } label: {
                        ContactRow(
                            name: "新的朋友",
                            icon: "person.badge.plus",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        showAddContact = true
                    } label: {
                        ContactRow(
                            name: "添加联系人",
                            icon: "person.crop.circle.badge.plus",
                            color: .green
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(filteredChats) { chat in
                        Button {
                            selectedChatID = chat.id
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    name: chat.name,
                                    size: 44
                                )

                                Text(chat.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.white.opacity(0.55))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: Profile

    private var profilePage: some View {
        VStack(spacing: 0) {
            header(title: "我")

            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        AvatarView(
                            name: "我",
                            size: 76
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("微信用户")
                                .font(.system(size: 22, weight: .bold))

                            Text("微信号：WeChatDemo")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "qrcode")
                            .font(.system(size: 22))
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(.white.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                    ProfileRow(
                        icon: "wallet.pass.fill",
                        title: "服务",
                        color: .blue
                    )

                    ProfileRow(
                        icon: "heart.fill",
                        title: "收藏",
                        color: .orange
                    )

                    ProfileRow(
                        icon: "photo.fill",
                        title: "朋友圈",
                        color: .pink
                    )

                    ProfileRow(
                        icon: "gearshape.fill",
                        title: "设置",
                        color: .gray
                    )

                    ProfileRow(
                        icon: "info.circle.fill",
                        title: "关于本应用",
                        color: .green
                    )
                }
                .padding(16)
            }
        }
    }

    // MARK: Header

    private func header(
        title: String,
        trailingIcon: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 25, weight: .bold))

            Spacer()

            if let trailingIcon {
                Button {
                    action?()
                } label: {
                    Image(systemName: trailingIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.65))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: Search

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索", text: $searchText)
                .font(.system(size: 15))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 5) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    switchTab(to: tab)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .symbolEffect(
                                .bounce,
                                value: selectedTab == tab
                            )

                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(
                        selectedTab == tab
                        ? Color.green
                        : Color.secondary
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                                .matchedGeometryEffect(
                                    id: "selectedTabGlass",
                                    in: tabAnimation
                                )
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(7)
        .liquidGlass(in: Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 5)
    }

    // MARK: Tab Animation

    private func switchTab(to tab: MainTab) {
        guard selectedTab != tab else {
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        withAnimation(
            .spring(
                response: 0.42,
                dampingFraction: 0.78
            )
        ) {
            selectedTab = tab
        }
    }

    // MARK: Swipe Navigation

    private func handlePageSwipe(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        let vertical = value.translation.height

        guard abs(horizontal) > abs(vertical) * 1.3 else {
            return
        }

        guard abs(horizontal) > 65 else {
            return
        }

        let tabs = MainTab.allCases

        guard let currentIndex = tabs.firstIndex(of: selectedTab) else {
            return
        }

        let nextIndex = horizontal < 0
            ? currentIndex + 1
            : currentIndex - 1

        guard tabs.indices.contains(nextIndex) else {
            return
        }

        switchTab(to: tabs[nextIndex])
    }
}

// MARK: - Chat Row

struct ChatRow: View {
    let chat: DemoChat

    var body: some View {
        HStack(spacing: 13) {
            AvatarView(
                name: chat.name,
                size: 54
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(chat.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(chat.lastMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(chat.updatedAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(13)
        .background(.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 19))
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let name: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 13))

            Text(name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundStyle(color)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let name: String
    var size: CGFloat = 48

    private var avatarColor: Color {
        let colors: [Color] = [
            .blue,
            .green,
            .orange,
            .purple,
            .pink,
            .teal
        ]

        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28)
                .fill(avatarColor.opacity(0.15))

            if name == "文件传输助手" {
                Image(systemName: "folder.fill")
                    .foregroundStyle(avatarColor)
                    .font(.system(size: size * 0.42))
            } else if name == "ChatGPT" {
                Image(systemName: "sparkles")
                    .foregroundStyle(avatarColor)
                    .font(.system(size: size * 0.42))
            } else {
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(avatarColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28))
    }
}

// MARK: - Chat Detail

struct ChatDetailView: View {

    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    let chatID: UUID

    @State private var messageText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @FocusState private var inputFocused: Bool

    private var chat: DemoChat? {
        store.chats.first {
            $0.id == chatID
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 15) {
                                if let chat {
                                    ForEach(chat.messages) { message in
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: chat?.messages.count ?? 0) {
                            _, _ in

                            guard let lastID = chat?.messages.last?.id else {
                                return
                            }

                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(
                                    lastID,
                                    anchor: .bottom
                                )
                            }
                        }
                    }

                    inputBar
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
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else {
                return
            }

            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        store.sendImage(image, to: chatID)
                        selectedPhoto = nil
                    }
                }
            }
        }
    }

    // MARK: Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Image(systemName: "photo")
                    .font(.system(size: 23))
                    .foregroundStyle(.green)
                    .frame(width: 38, height: 42)
            }

            TextField("发送消息...", text: $messageText, axis: .vertical)
                .font(.system(size: 15))
                .lineLimit(1...4)
                .padding(11)
                .background(.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .focused($inputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 31))
                    .foregroundStyle(.green)
            }
            .disabled(
                messageText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func sendMessage() {
        store.sendText(messageText, to: chatID)
        messageText = ""
        inputFocused = false
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: DemoMessage

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if !message.incoming {
                Spacer(minLength: 45)
            }

            if message.incoming {
                AvatarView(name: "对方", size: 36)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let path = message.imagePath,
                   let url = mediaURL(path),
                   let image = UIImage(contentsOfFile: url.path) {

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 13))

                } else {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .background(
                            message.incoming
                            ? Color.white
                            : Color.green.opacity(0.22)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }

                Text(message.time, style: .time)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if message.incoming {
                Spacer(minLength: 45)
            } else {
                AvatarView(name: "我", size: 36)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func mediaURL(_ path: String) -> URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("Media")
        .appendingPathComponent(path)
    }
}

// MARK: - Moments

struct MomentsView: View {

    @EnvironmentObject var store: ChatStore
    @State private var showPublish = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("发现")
                    .font(.system(size: 25, weight: .bold))

                Spacer()

                Button {
                    showPublish = true
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.white.opacity(0.65))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            ScrollView {
                VStack(spacing: 14) {
                    DiscoverRow(
                        icon: "person.2.fill",
                        title: "朋友圈",
                        color: .green
                    )

                    DiscoverRow(
                        icon: "play.rectangle.fill",
                        title: "视频号",
                        color: .pink
                    )

                    DiscoverRow(
                        icon: "safari.fill",
                        title: "扫一扫",
                        color: .blue
                    )

                    DiscoverRow(
                        icon: "gamecontroller.fill",
                        title: "游戏",
                        color: .orange
                    )

                    DiscoverRow(
                        icon: "miniature.2",
                        title: "小程序",
                        color: .purple
                    )

                    if !store.moments.isEmpty {
                        Text("最近朋友圈")
                            .font(.system(size: 18, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 12)

                        ForEach(store.moments) { moment in
                            MomentRow(moment: moment)
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showPublish) {
            PublishMomentView()
                .environmentObject(store)
        }
    }
}

// MARK: - Discover Row

struct DiscoverRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 30)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(17)
        .background(.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }
}

// MARK: - Moment Row

struct MomentRow: View {
    let moment: DemoMoment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(name: "我", size: 45)

            VStack(alignment: .leading, spacing: 9) {
                Text("微信用户")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.blue)

                if !moment.text.isEmpty {
                    Text(moment.text)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                }

                if let path = moment.imagePath,
                   let url = mediaURL(path),
                   let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 230)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                HStack {
                    Text(moment.time, style: .date)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    private func mediaURL(_ path: String) -> URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        .appendingPathComponent("Media")
        .appendingPathComponent(path)
    }
}

// MARK: - Publish Moment

struct PublishMomentView: View {

    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                TextEditor(text: $text)
                    .frame(minHeight: 150)
                    .padding(8)
                    .background(.white.opacity(0.75))
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("这一刻的想法...")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                }

                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label("选择照片", systemImage: "photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(.white.opacity(0.75))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer()
            }
            .padding(16)
            .background(AppBackground())
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
                            text: text,
                            image: selectedImage
                        )
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(
                        text.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty && selectedImage == nil
                    )
                }
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else {
                return
            }

            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        selectedImage = image
                        selectedPhoto = nil
                    }
                }
            }
        }
    }
}
