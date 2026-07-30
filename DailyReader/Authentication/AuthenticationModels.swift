import Foundation

enum AuthenticationAvailability: Equatable, Sendable {
    case configured
    case unconfigured(UnconfiguredReason)
}

enum UnconfiguredReason: String, Equatable, Sendable {
    case missingRequiredValues
    case invalidEndpoint
    case invalidRedirect
    case invalidOriginPolicy
    case unsupportedContract
}

enum AuthenticationProgress: Equatable, Sendable {
    case preparingAuthorization
    case authorizing
    case processingCallback
    case loadingProfile
    case restoring
}

enum AuthenticationError: Error, Equatable, Sendable {
    case configurationUnavailable
    case operationAlreadyInProgress
    case userCancelled
    case authorizationDenied
    case invalidCallback
    case missingState
    case stateMismatch
    case duplicateCallbackParameter
    case callbackAlreadyConsumed
    case missingAuthorizationCode
    case transactionExpired
    case transportFailure
    case serviceFailure
    case invalidResponse
    case invalidSession
    case profileFailure
    case refreshFailure
    case secureStorageFailure

    var displayMessage: String {
        switch self {
        case .configurationUnavailable: return "知乎登录暂不可用"
        case .operationAlreadyInProgress: return "登录正在处理中"
        case .userCancelled: return "已取消登录"
        case .authorizationDenied: return "未获得授权，尚未登录"
        case .invalidCallback, .missingState, .stateMismatch, .duplicateCallbackParameter,
             .callbackAlreadyConsumed, .missingAuthorizationCode, .transactionExpired:
            return "登录回调无效，请重新登录"
        case .transportFailure: return "网络连接失败，请重试"
        case .serviceFailure: return "登录服务暂时不可用，请重试"
        case .invalidResponse: return "登录服务响应无效，请重试"
        case .invalidSession: return "登录已失效，请重新登录"
        case .profileFailure: return "获取账号资料失败，请重试"
        case .refreshFailure: return "刷新登录状态失败，请重新登录"
        case .secureStorageFailure: return "无法安全保存登录状态，请重试"
        }
    }
}

struct AuthUserProfile: Codable, Equatable, Sendable {
    let subject: String
    let displayName: String
    let avatarURL: URL?

    init(subject: String, displayName: String, avatarURL: URL?) throws {
        let normalizedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSubject.isEmpty, !normalizedName.isEmpty else {
            throw AuthenticationError.profileFailure
        }
        self.subject = normalizedSubject
        self.displayName = normalizedName
        self.avatarURL = avatarURL
    }
}

struct OAuthTokenSet: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let tokenType: String
    let expiresAt: Date?
    let grantedScopes: [String]

    init(accessToken: String, refreshToken: String?, tokenType: String, expiresAt: Date?, grantedScopes: [String]) throws {
        guard !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              tokenType.caseInsensitiveCompare("Bearer") == .orderedSame else {
            throw AuthenticationError.invalidResponse
        }
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
        self.grantedScopes = grantedScopes
    }
}

struct StoredAuthSession: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let tokenSet: OAuthTokenSet

    init(tokenSet: OAuthTokenSet, schemaVersion: Int = currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.tokenSet = tokenSet
    }
}

struct AuthorizationTransaction: Equatable, Sendable {
    let id: UUID
    let state: String
    let verifier: String
    let createdAt: Date
    var callbackConsumed: Bool
}

struct ValidatedAuthorizationCode: Equatable, Sendable {
    let value: String
}

enum RetryIntent: Equatable, Sendable {
    case signIn
    case restore
    case profile
}

struct AuthenticationFailure: Equatable, Sendable {
    let message: String
    let retryIntent: RetryIntent?
}

enum AuthenticationState: Equatable, Sendable {
    case unconfigured
    case signedOut(notice: String?)
    case preparingAuthorization
    case authorizing
    case processingCallback
    case loadingProfile
    case restoring
    case retryableFailure(AuthenticationFailure)
    case invalidCallback(message: String)
    case sessionExpired(message: String)
    case signedIn(AuthUserProfile)
    case signingOut(AuthUserProfile)
}

struct SignOutResult: Equatable, Sendable {
    let localSessionRemoved: Bool
    let remoteRevocationFailed: Bool
}
