import SwiftUI

struct AIChatContainer: View {
    @EnvironmentObject private var coordinator: AIChatCoordinator
    @StateObject private var viewModel: AIChatViewModel
    private let currentArticleContext: AIArticleContext?

    @MainActor
    init(presentation: AIChatPresentation, coordinator: AIChatCoordinator) {
        _viewModel = StateObject(wrappedValue: coordinator.makeChatViewModel(sessionID: presentation.sessionID))
        currentArticleContext = presentation.currentArticleContext
    }

    var body: some View {
        AIChatView(viewModel: viewModel, currentArticleContext: currentArticleContext)
            .environmentObject(coordinator)
    }
}

struct AIChatView: View {
    @ObservedObject var viewModel: AIChatViewModel
    let currentArticleContext: AIArticleContext?

    @EnvironmentObject private var coordinator: AIChatCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var showsSessions = false
    @State private var showsContext = false
    @State private var showsSettings = false
    @State private var showsDeleteConfirmation = false
    @State private var showsReplaceConfirmation = false
    @FocusState private var composerFocused: Bool

    private var hasContextConflict: Bool {
        guard let currentArticleContext else { return false }
        return viewModel.session.articleContext?.id != currentArticleContext.id
    }

    var body: some View {
        GeometryReader { geometry in
            NavigationStack {
                VStack(spacing: 0) {
                if let context = viewModel.session.articleContext {
                    articleContextBar(context)
                }
                if hasContextConflict, let currentArticleContext {
                    contextConflictBanner(currentArticleContext)
                }
                if !viewModel.hasAvailableProviders {
                    providerConfigurationBanner
                }
                messageContent
            }
            .background(DS.paper.ignoresSafeArea())
            .navigationTitle(viewModel.session.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.stop()
                        coordinator.dismiss()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("关闭 AI 对话")
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        showsSessions = true
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.session.title)
                                .font(DS.songBold(16))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .truncationMode(.tail)
                                .layoutPriority(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(DS.inkSecondary)
                        }
                        .foregroundStyle(DS.ink)
                        .frame(width: min(max(geometry.size.width * 0.52, 150), 230))
                        .clipped()
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("切换对话，当前为\(viewModel.session.title)")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            _ = coordinator.newSession(articleContext: currentArticleContext)
                        } label: {
                            Label("新建对话", systemImage: "plus")
                        }
                        if viewModel.session.articleContext != nil {
                            Button {
                                showsContext = true
                            } label: {
                                Label("查看文章上下文", systemImage: "doc.text.magnifyingglass")
                            }
                        }
                        Button {
                            showsSettings = true
                        } label: {
                            Label("AI 服务设置", systemImage: "gearshape")
                        }
                        Button(role: .destructive) {
                            showsDeleteConfirmation = true
                        } label: {
                            Label("删除对话", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("更多操作")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
        }
        .tint(DS.indigo)
        .sheet(isPresented: $showsSessions) {
            AISessionListView(currentSessionID: viewModel.session.id)
                .environmentObject(coordinator)
        }
        .onChange(of: showsSessions) { _, isPresented in
            if !isPresented {
                viewModel.refreshFromCoordinator()
            }
        }
        .sheet(isPresented: $showsContext) {
            if let context = viewModel.session.articleContext {
                AIArticleContextView(context: context)
            }
        }
        .sheet(isPresented: $showsSettings) {
            NavigationStack {
                AIConfigurationView(store: coordinator.configurationStore)
            }
        }
        .confirmationDialog("删除这个对话？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("删除对话", role: .destructive) {
                coordinator.deleteSession(id: viewModel.session.id)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("消息与绑定的文章上下文将从本机移除，此操作无法撤销。")
        }
        .confirmationDialog("替换文章上下文？", isPresented: $showsReplaceConfirmation, titleVisibility: .visible) {
            if let currentArticleContext {
                Button("替换上下文", role: .destructive) {
                    viewModel.replaceArticleContext(currentArticleContext)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("后续回答将使用当前文章；历史回答不会重新计算。")
        }
        }
    }

    private func articleContextBar(_ context: AIArticleContext) -> some View {
        Button {
            showsContext = true
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("当前文章")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(DS.indigo)
                    Text(context.title)
                        .font(DS.songBold(14))
                        .foregroundStyle(DS.ink)
                        .lineLimit(1)
                    Text(context.isTruncated ? "上下文已压缩" : "已引入全文 · \(context.text.count) 字")
                        .font(.caption2)
                        .foregroundStyle(context.isTruncated ? DS.ochre : DS.inkSecondary)
                }
                Spacer(minLength: 8)
                Text("查看")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.indigo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(DS.paperElevated)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.hairline).frame(height: 0.7)
        }
        .accessibilityLabel("当前文章，\(context.title)，轻点查看上下文")
    }

    private func contextConflictBanner(_ context: AIArticleContext) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(viewModel.session.articleContext.map {
                "当前会话使用《\($0.title)》，你正在阅读《\(context.title)》。"
            } ?? "当前是独立对话，你正在阅读《\(context.title)》。")
                .font(.system(size: 13))
                .foregroundStyle(DS.ink)
            HStack(spacing: 16) {
                Button("为当前文章新建对话") {
                    _ = coordinator.newSession(articleContext: context)
                }
                .font(.system(size: 13, weight: .semibold))
                Button(viewModel.session.articleContext == nil ? "绑定当前文章" : "替换上下文") {
                    showsReplaceConfirmation = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.cinnabar)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.indigo.opacity(0.08))
        .overlay(alignment: .bottom) { Rectangle().fill(DS.hairline).frame(height: 0.7) }
    }

    private var providerConfigurationBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(DS.cinnabar)
            VStack(alignment: .leading, spacing: 4) {
                Text("尚无可用 AI 服务")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.ink)
                Text("请先启用内置服务，或配置你自己的 OpenAI 兼容 Endpoint。")
                    .font(.caption)
                    .foregroundStyle(DS.inkSecondary)
            }
            Spacer(minLength: 8)
            Button("去设置") {
                showsSettings = true
            }
            .font(.system(size: 13, weight: .semibold))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.cinnabar.opacity(0.07))
        .overlay(alignment: .bottom) { Rectangle().fill(DS.hairline).frame(height: 0.7) }
    }

    @ViewBuilder
    private var messageContent: some View {
        if viewModel.session.messages.isEmpty {
            AIChatEmptyView(articleContext: viewModel.session.articleContext) { prompt in
                if viewModel.session.articleContext == nil {
                    viewModel.updateDraft(prompt)
                    composerFocused = true
                } else {
                    viewModel.send(prompt: prompt)
                }
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if let selection = viewModel.session.articleContext?.focusedSelection, !selection.isEmpty {
                            focusedQuote(selection)
                        }
                        ForEach(viewModel.session.messages) { message in
                            messageRow(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .onChange(of: viewModel.session.messages.last?.content) { _, _ in
                    guard let id = viewModel.session.messages.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.16)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(for message: AIChatMessage) -> some View {
        if message.role == .assistant && message.state != .complete {
            AIMessageView(
                message: message,
                isThinking: viewModel.isThinking && message.id == viewModel.session.messages.last?.id,
                retry: { viewModel.retryLast() }
            )
        } else {
            AIMessageView(message: message, isThinking: false, retry: nil)
        }
    }

    private func focusedQuote(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("你选择的段落")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.indigo)
            Text(text)
                .font(DS.songBold(14))
                .foregroundStyle(DS.ink)
                .lineLimit(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.paperElevated)
        .overlay(alignment: .leading) { Rectangle().fill(DS.indigo).frame(width: 3) }
    }

    private var composer: some View {
        VStack(spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(errorMessage).frame(maxWidth: .infinity, alignment: .leading)
                    Button("重试", action: viewModel.retryLast)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(DS.cinnabar)
                .padding(.horizontal, 4)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(
                    viewModel.session.articleContext == nil ? "输入问题…" : "向当前文章提问…",
                    text: Binding(get: { viewModel.draft }, set: viewModel.updateDraft),
                    axis: .vertical
                )
                .lineLimit(1...6)
                .focused($composerFocused)
                .accessibilityIdentifier("ai.chat.composer")
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(DS.paperElevated)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(composerFocused ? DS.indigo : DS.hairline, lineWidth: composerFocused ? 1.5 : 0.7)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    viewModel.isGenerating ? viewModel.stop() : viewModel.send()
                } label: {
                    Image(systemName: viewModel.isGenerating ? "stop.fill" : "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(viewModel.isGenerating || viewModel.canSend ? DS.indigo : DS.indigo.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!viewModel.isGenerating && !viewModel.canSend)
                .accessibilityLabel(viewModel.isGenerating ? "停止生成" : "发送")
            }
            HStack(spacing: 5) {
                if viewModel.isGenerating {
                    Text(viewModel.isThinking ? "正在思考" : "正在连接 AI 服务")
                        .foregroundStyle(DS.indigo)
                } else {
                    Text(viewModel.providerSummary)
                }
                if viewModel.session.articleContext != nil { Text("· 文章上下文") }
                Spacer()
                if !viewModel.hasAvailableProviders {
                    Button("配置服务") { showsSettings = true }
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.cinnabar)
                }
            }
            .font(.caption2)
            .foregroundStyle(DS.inkSecondary)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(DS.paper)
        .overlay(alignment: .top) { Rectangle().fill(DS.hairline).frame(height: 0.7) }
    }
}

private struct AIChatEmptyView: View {
    let articleContext: AIArticleContext?
    let selectPrompt: (String) -> Void

    private var prompts: [String] {
        if articleContext != nil {
            return ["用三句话总结这篇文章", "解释文中的核心概念", "查证文章中的关键结论"]
        }
        return ["比较两个观点的异同", "解释一个我没弄懂的概念", "帮我列出查证某个观点的步骤"]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 14) {
                Text("知")
                    .font(DS.songBlack(24))
                    .foregroundStyle(DS.indigo)
                    .frame(width: 52, height: 52)
                    .overlay { RoundedRectangle(cornerRadius: 5).stroke(DS.indigo, lineWidth: 1) }
                    .padding(.top, 58)
                Text(articleContext == nil ? "今天想了解什么？" : "从这篇文章开始问")
                    .font(DS.songBlack(24))
                    .foregroundStyle(DS.ink)
                Text(articleContext == nil ? "可以提问、比较观点，或让模型按需搜索。" : "已将《\(articleContext?.title ?? "当前文章")》作为当前对话背景。")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                VStack(spacing: 9) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                        Button(prompt) { selectPrompt(prompt) }
                            .font(.system(size: 14))
                            .foregroundStyle(DS.ink)
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                            .background(DS.paperElevated)
                            .overlay { RoundedRectangle(cornerRadius: 10).stroke(DS.hairline, lineWidth: 0.7) }
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("ai.quickPrompt.\(index)")
                            .accessibilityHint(articleContext == nil ? "填入输入框" : "立即发送")
                    }
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 24)
        }
    }
}

private struct AIMessageView: View {
    let message: AIChatMessage
    let isThinking: Bool
    let retry: (() -> Void)?
    @State private var copied = false

    var body: some View {
        Group {
            if message.role == .user {
                Text(message.content)
                    .font(.system(size: 16))
                    .foregroundStyle(DS.ink)
                    .lineSpacing(3)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(DS.indigo.opacity(0.10))
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 12, bottomLeading: 12, bottomTrailing: 4, topTrailing: 12)))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 42)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Text("知")
                            .font(DS.songBold(10))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(DS.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Text(message.providerName.map { "AI 批注 · \($0)" } ?? "AI 批注")
                            .font(DS.songBold(14))
                            .foregroundStyle(DS.ink)
                            .lineLimit(1)
                    }
                    if message.content.isEmpty && message.state == .streaming {
                        HStack(spacing: 8) {
                            ProgressView().tint(DS.indigo)
                            Text(isThinking ? "正在思考" : "正在连接 AI 服务")
                                .font(.caption)
                                .foregroundStyle(DS.inkSecondary)
                        }
                    } else {
                        Text(message.content)
                            .font(.system(size: 17))
                            .foregroundStyle(DS.ink)
                            .textSelection(.enabled)
                            .lineSpacing(5)
                    }
                    if let searchSummary = message.searchSummary {
                        Label(searchSummary, systemImage: message.citations.isEmpty ? "magnifyingglass" : "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(message.citations.isEmpty ? DS.indigo : Color(red: 63 / 255, green: 107 / 255, blue: 69 / 255))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background((message.citations.isEmpty ? DS.indigo : Color(red: 63 / 255, green: 107 / 255, blue: 69 / 255)).opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if !message.citations.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(message.citations.enumerated()), id: \.element.id) { index, citation in
                                AICitationRow(index: index + 1, citation: citation)
                                if index < message.citations.count - 1 { Divider().overlay(DS.hairline) }
                            }
                        }
                        .overlay(alignment: .top) { Rectangle().fill(DS.hairline).frame(height: 0.7) }
                    }
                    if message.state != .streaming {
                        HStack(spacing: 18) {
                            Button(copied ? "已复制" : "复制") {
                                UIPasteboard.general.string = message.content
                                copied = true
                                Task {
                                    try? await Task.sleep(for: .seconds(1.2))
                                    copied = false
                                }
                            }
                            if let retry { Button("重新生成", action: retry) }
                            if message.state == .interrupted { Text("回答已停止") }
                            if message.state == .failed { Text("请求失败").foregroundStyle(DS.cinnabar) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.indigo)
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) { Rectangle().fill(DS.indigo).frame(width: 2) }
            }
        }
    }
}

private struct AICitationRow: View {
    let index: Int
    let citation: AICitation

    var body: some View {
        Group {
            if let destination = validatedDestination {
                Link(destination: destination) { rowContent(showsExternalLink: true) }
            } else {
                rowContent(showsExternalLink: false)
            }
        }
        .padding(.vertical, 10)
    }

    private var validatedDestination: URL? {
        guard let url = URL(string: citation.url),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host?.isEmpty == false else { return nil }
        return url
    }

    private func rowContent(showsExternalLink: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.caption2.bold())
                .foregroundStyle(DS.indigo)
                .frame(width: 22, height: 22)
                .overlay { Circle().stroke(DS.indigo, lineWidth: 1) }
            VStack(alignment: .leading, spacing: 3) {
                Text(citation.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.ink)
                Text(validatedDestination?.host ?? citation.url)
                    .font(.caption2)
                    .foregroundStyle(DS.inkSecondary)
                if let snippet = citation.snippet {
                    Text(snippet)
                        .font(.caption)
                        .foregroundStyle(DS.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            if showsExternalLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(DS.indigo)
            }
        }
    }
}

private struct AISessionListView: View {
    @EnvironmentObject private var coordinator: AIChatCoordinator
    @Environment(\.dismiss) private var dismiss
    let currentSessionID: UUID
    @State private var sessionToDelete: AIChatSession?
    @State private var sessionToRename: AIChatSession?
    @State private var renameTitle = ""

    var body: some View {
        NavigationStack {
            List {
                if coordinator.sessions.isEmpty {
                    ContentUnavailableView("还没有对话", systemImage: "text.bubble", description: Text("从文章中提问，或创建一个独立对话。"))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(coordinator.sessions) { session in
                        Button {
                            coordinator.selectSession(id: session.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(session.id == currentSessionID ? DS.indigo : Color.clear)
                                    .frame(width: 3, height: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(session.title)
                                            .font(DS.songBold(16))
                                            .foregroundStyle(DS.ink)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(session.updatedAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(DS.inkSecondary)
                                    }
                                    Text(session.articleContext.map { "文章 · \($0.title)" } ?? "独立对话")
                                        .font(.caption)
                                        .foregroundStyle(session.articleContext == nil ? DS.inkSecondary : DS.indigo)
                                        .lineLimit(1)
                                    Text(session.messages.last?.content ?? "还没有消息")
                                        .font(.caption)
                                        .foregroundStyle(DS.inkSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(session.id == currentSessionID ? DS.paperElevated : Color.clear)
                        .swipeActions {
                            Button(role: .destructive) { sessionToDelete = session } label: { Label("删除", systemImage: "trash") }
                            Button {
                                renameTitle = session.title
                                sessionToRename = session
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            .tint(DS.indigo)
                        }
                        .contextMenu {
                            Button {
                                renameTitle = session.title
                                sessionToRename = session
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                sessionToDelete = session
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .accessibilityAddTraits(session.id == currentSessionID ? .isSelected : [])
                    }
                }
            }
            .listStyle(.plain)
            .paperListBackground()
            .navigationTitle("对话记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        _ = coordinator.newSession(articleContext: nil)
                        dismiss()
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新对话")
                }
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .alert("重命名对话", isPresented: Binding(
            get: { sessionToRename != nil },
            set: { if !$0 { sessionToRename = nil } }
        )) {
            TextField("对话名称", text: $renameTitle)
            Button("保存") {
                if let sessionToRename {
                    coordinator.renameSession(id: sessionToRename.id, title: renameTitle)
                }
                sessionToRename = nil
                renameTitle = ""
            }
            Button("取消", role: .cancel) {
                sessionToRename = nil
                renameTitle = ""
            }
        } message: {
            Text("名称仅保存在本机。")
        }
        .confirmationDialog("删除这个对话？", isPresented: Binding(get: { sessionToDelete != nil }, set: { if !$0 { sessionToDelete = nil } })) {
            Button("删除对话", role: .destructive) {
                if let sessionToDelete { coordinator.deleteSession(id: sessionToDelete.id) }
                sessionToDelete = nil
            }
            Button("取消", role: .cancel) { sessionToDelete = nil }
        }
    }
}

private struct AIArticleContextView: View {
    let context: AIArticleContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(context.title)
                        .font(DS.songBlack(24))
                        .foregroundStyle(DS.ink)
                    HStack {
                        Label(context.isTruncated ? "上下文已压缩" : "已保存全文", systemImage: context.isTruncated ? "exclamationmark.triangle" : "checkmark.circle")
                        Spacer()
                        Text("\(context.text.count) 字")
                    }
                    .font(.caption)
                    .foregroundStyle(context.isTruncated ? DS.ochre : DS.inkSecondary)
                    RuleLine()
                    if let selection = context.focusedSelection, !selection.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("你选择的段落").font(.caption.bold()).foregroundStyle(DS.indigo)
                            Text(selection).font(.system(size: 16)).textSelection(.enabled)
                        }
                        .padding(12)
                        .background(DS.indigo.opacity(0.08))
                    }
                    Text(context.text)
                        .font(.system(size: 16))
                        .foregroundStyle(DS.ink)
                        .lineSpacing(5)
                        .textSelection(.enabled)
                }
                .padding(18)
            }
            .background(DS.paper.ignoresSafeArea())
            .navigationTitle("文章上下文")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
