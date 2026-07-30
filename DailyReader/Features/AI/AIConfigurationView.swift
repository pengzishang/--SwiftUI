import SwiftUI

struct AIConfigurationView: View {
    @ObservedObject var store: AIConfigurationStore
    @State private var testingProviderID: String?
    @State private var feedback: [String: ProviderFeedback] = [:]
    @State private var connectionTestTask: Task<Void, Never>?
    @State private var showsUserEditor = false
    @Environment(\.editMode) private var editMode

    var body: some View {
        List {
            Section {
                ForEach(store.providers) { provider in
                    providerRow(provider)
                }
                .onMove(perform: store.moveProviders)

                if store.userProvider == nil {
                    Button {
                        showsUserEditor = true
                    } label: {
                        Label("添加我的服务", systemImage: "plus.circle")
                            .foregroundStyle(DS.indigo)
                    }
                }
            } header: {
                sectionHeader("服务顺序")
            } footer: {
                Text("发送时会并行请求所有已启用服务，采用第一个返回有效正文的回答，可能产生多份调用费用。")
            }

            Section {
                Text("内置凭据通过本机构建配置注入并导入钥匙串，不会显示在界面中。构建注入不能防止安装包被逆向提取，正式发布应使用后端代理。")
                    .font(.system(size: 14))
                    .foregroundStyle(DS.inkSecondary)
                    .lineSpacing(4)
            } header: {
                sectionHeader("安全说明")
            }
        }
        .scrollContentBackground(.hidden)
        .background(DS.paper.ignoresSafeArea())
        .navigationTitle("AI 服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showsUserEditor) {
            NavigationStack {
                AIUserProviderEditor(store: store)
            }
        }
        .onDisappear {
            connectionTestTask?.cancel()
            connectionTestTask = nil
        }
    }

    private func providerRow(_ provider: AIProviderProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(provider.name)
                            .font(DS.songBold(16))
                            .foregroundStyle(DS.ink)
                        if provider.isBuiltIn {
                            Text("内置")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.indigo)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DS.indigo.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    Text(provider.isBuiltIn ? "流式竞速服务" : provider.configuration.model)
                        .font(.caption)
                        .foregroundStyle(DS.inkSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { provider.isEnabled },
                    set: { store.setEnabled($0, providerID: provider.id) }
                ))
                .labelsHidden()
                .tint(DS.indigo)
            }

            if let status = feedback[provider.id] {
                Label(status.message, systemImage: status.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(status.isSuccess ? Color.green : DS.cinnabar)
            }

            if editMode?.wrappedValue.isEditing != true {
                HStack(spacing: 16) {
                    Button(testingProviderID == provider.id ? "正在测试" : "测试连接") {
                        test(provider)
                    }
                    .disabled(
                        testingProviderID != nil
                            || store.runtimeProviders(providerID: provider.id, includeDisabled: true).isEmpty
                    )

                    if provider.source == .user {
                        Button("编辑") { showsUserEditor = true }
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(DS.indigo)
            }
        }
        .padding(.vertical, 5)
        .listRowBackground(DS.paperElevated)
    }

    private func test(_ provider: AIProviderProfile) {
        testingProviderID = provider.id
        feedback[provider.id] = nil
        let providers = store.runtimeProviders(providerID: provider.id, includeDisabled: true)
        connectionTestTask?.cancel()
        connectionTestTask = Task {
            do {
                try await AIRacingChatService().testConnection(providers: providers)
                guard !Task.isCancelled else { return }
                feedback[provider.id] = .success("连接成功 · 已返回有效正文")
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                feedback[provider.id] = .failure(
                    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                )
            }
            testingProviderID = nil
            connectionTestTask = nil
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(DS.songBold(13))
            .foregroundStyle(DS.inkSecondary)
            .textCase(nil)
    }
}

private struct AIUserProviderEditor: View {
    @ObservedObject var store: AIConfigurationStore
    @Environment(\.dismiss) private var dismiss
    @State private var endpoint: String
    @State private var model: String
    @State private var apiKey = ""
    @State private var allowsSearchTools: Bool
    @State private var showsAPIKey = false
    @State private var feedback: String?

    init(store: AIConfigurationStore) {
        self.store = store
        let configuration = store.userProvider?.configuration ?? .empty
        _endpoint = State(initialValue: configuration.endpoint)
        _model = State(initialValue: configuration.model)
        _allowsSearchTools = State(initialValue: configuration.allowsSearchTools)
    }

    var body: some View {
        Form {
            Section("OpenAI 兼容服务") {
                TextField("https://api.example.com/v1", text: $endpoint)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                TextField("模型", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                HStack {
                    Group {
                        if showsAPIKey {
                            TextField(keyPlaceholder, text: $apiKey)
                        } else {
                            SecureField(keyPlaceholder, text: $apiKey)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    Button {
                        showsAPIKey.toggle()
                    } label: {
                        Image(systemName: showsAPIKey ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(showsAPIKey ? "隐藏 API Key" : "显示 API Key")
                }

                Toggle("允许模型使用搜索工具", isOn: $allowsSearchTools)
                    .tint(DS.indigo)
            }

            if let feedback {
                Section {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(DS.cinnabar)
                }
            }
        }
        .navigationTitle("我的服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    private var candidate: AIConfiguration {
        AIConfiguration(
            endpoint: endpoint.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines),
            allowsSearchTools: allowsSearchTools
        )
    }

    private var keyPlaceholder: String {
        store.hasAPIKey ? "已保存 · 留空以保留" : "API Key"
    }

    private var canSave: Bool {
        candidate.isComplete && (
            store.hasAPIKey || !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private func save() {
        do {
            try store.saveUserProvider(configuration: candidate, apiKey: apiKey)
            dismiss()
        } catch {
            feedback = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private enum ProviderFeedback {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let value), .failure(let value): return value
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
