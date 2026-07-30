import Foundation

enum AIMessageRole: String, Codable, Sendable {
    case user
    case assistant
}

enum AIMessageState: String, Codable, Sendable {
    case complete
    case streaming
    case interrupted
    case failed
}

struct AICitation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var url: String
    var snippet: String?

    init(id: UUID = UUID(), title: String, url: String, snippet: String? = nil) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
    }
}

struct AIChatMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var role: AIMessageRole
    var content: String
    var createdAt: Date
    var state: AIMessageState
    var citations: [AICitation]
    var searchSummary: String?
    var providerName: String?

    init(
        id: UUID = UUID(),
        role: AIMessageRole,
        content: String,
        createdAt: Date = Date(),
        state: AIMessageState = .complete,
        citations: [AICitation] = [],
        searchSummary: String? = nil,
        providerName: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.state = state
        self.citations = citations
        self.searchSummary = searchSummary
        self.providerName = providerName
    }
}

struct AIArticleContext: Identifiable, Codable, Equatable, Sendable {
    let id: Int
    var title: String
    var text: String
    var sourceURL: String?
    var focusedSelection: String?
    var capturedAt: Date
    var isTruncated: Bool

    init(
        id: Int,
        title: String,
        text: String,
        sourceURL: String? = nil,
        focusedSelection: String? = nil,
        capturedAt: Date = Date(),
        isTruncated: Bool = false
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.sourceURL = sourceURL
        self.focusedSelection = focusedSelection
        self.capturedAt = capturedAt
        self.isTruncated = isTruncated
    }
}

struct AIChatSession: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var articleContext: AIArticleContext?
    var messages: [AIChatMessage]
    var draft: String

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        articleContext: AIArticleContext? = nil,
        messages: [AIChatMessage] = [],
        draft: String = ""
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.articleContext = articleContext
        self.messages = messages
        self.draft = draft
    }
}

enum AIProviderSource: String, Codable, Sendable {
    case user
    case builtIn
}

struct AIProviderLaneProfile: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var configuration: AIConfiguration
}

struct AIProviderProfile: Identifiable, Codable, Equatable, Sendable {
    let id: String
    var name: String
    var lanes: [AIProviderLaneProfile]
    var source: AIProviderSource
    var isEnabled: Bool

    init(
        id: String,
        name: String,
        lanes: [AIProviderLaneProfile],
        source: AIProviderSource,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.lanes = lanes
        self.source = source
        self.isEnabled = isEnabled
    }

    init(
        id: String,
        name: String,
        configuration: AIConfiguration,
        source: AIProviderSource,
        isEnabled: Bool = true
    ) {
        self.init(
            id: id,
            name: name,
            lanes: [AIProviderLaneProfile(id: id, configuration: configuration)],
            source: source,
            isEnabled: isEnabled
        )
    }

    var isBuiltIn: Bool { source == .builtIn }

    var configuration: AIConfiguration {
        get { lanes.first?.configuration ?? .empty }
        set {
            if lanes.isEmpty {
                lanes = [AIProviderLaneProfile(id: id, configuration: newValue)]
            } else {
                lanes[0].configuration = newValue
            }
        }
    }
}

struct AIProviderRuntimeConfiguration: Sendable {
    let providerID: String
    let providerName: String
    let laneID: String
    let configuration: AIConfiguration
    let apiKey: String

    init(
        providerID: String,
        providerName: String,
        laneID: String,
        configuration: AIConfiguration,
        apiKey: String
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.laneID = laneID
        self.configuration = configuration
        self.apiKey = apiKey
    }

    init(profile: AIProviderProfile, apiKey: String) {
        let lane = profile.lanes.first ?? AIProviderLaneProfile(id: profile.id, configuration: .empty)
        self.init(
            providerID: profile.id,
            providerName: profile.name,
            laneID: lane.id,
            configuration: lane.configuration,
            apiKey: apiKey
        )
    }
}

struct AIConfiguration: Codable, Equatable, Sendable {
    var endpoint: String
    var model: String
    var allowsSearchTools: Bool

    static let empty = AIConfiguration(endpoint: "", model: "", allowsSearchTools: true)

    var normalizedEndpointURL: URL? {
        Self.endpointURL(from: endpoint)
    }

    var isComplete: Bool {
        normalizedEndpointURL != nil && !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func endpointURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains(where: { $0.isWhitespace }),
              var components = URLComponents(string: trimmed),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false else {
            return nil
        }
        let normalizedPath = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .joined(separator: "/")
        if normalizedPath.hasSuffix("chat/completions") {
            components.path = "/" + normalizedPath
        } else if normalizedPath.isEmpty {
            components.path = "/chat/completions"
        } else {
            components.path = "/" + normalizedPath + "/chat/completions"
        }
        return components.url
    }
}

enum AIChatError: LocalizedError, Equatable {
    case notConfigured
    case noAvailableProviders
    case missingAPIKey
    case invalidEndpoint
    case httpStatus(Int, String?)
    case invalidResponse
    case emptyResponse
    case allProvidersFailed(Int, String?)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "尚未配置 AI 服务"
        case .noAvailableProviders:
            return "暂无可用 AI 服务，请前往设置启用或配置"
        case .missingAPIKey:
            return "缺少 API Key，请前往设置补充"
        case .invalidEndpoint:
            return "Endpoint 无效，请检查 HTTPS 地址"
        case .httpStatus(let code, _):
            switch code {
            case 401, 403: return "认证失败，请检查 API Key"
            case 404: return "未找到兼容接口，请检查 Endpoint 路径"
            case 429: return "请求过于频繁，请稍后重试"
            case 500...599: return "AI 服务暂时不可用，请稍后重试"
            default: return "AI 请求失败（HTTP \(code)）"
            }
        case .invalidResponse:
            return "AI 服务返回了无法识别的数据"
        case .emptyResponse:
            return "AI 服务未返回可显示的正文"
        case .allProvidersFailed(_, let detail):
            return detail ?? "AI 服务均不可用，请稍后重试"
        case .transport(let message):
            return message.isEmpty ? "网络连接失败" : message
        }
    }
}

enum AIStreamFinishReason: Equatable, Sendable {
    case stop
    case length
    case other(String)
}

enum AIStreamEvent: Equatable, Sendable {
    case thinking
    case providerSelected(id: String, name: String)
    case text(String)
    case searchStatus(String)
    case citations([AICitation])
    case finished(AIStreamFinishReason)
}
