import Foundation

@MainActor
final class AuthenticationViewModel: ObservableObject {
    @Published private(set) var state: AuthenticationState
    @Published var isShowingSignOutConfirmation = false

    private let service: any AuthenticationServicing
    private var operationTask: Task<Void, Never>?
    private var operationID = UUID()
    private var retryIntent: RetryIntent?
    private var didRestore = false

    init(service: any AuthenticationServicing) {
        self.service = service
        switch service.availability {
        case .configured: state = .signedOut(notice: nil)
        case .unconfigured: state = .unconfigured
        }
    }

    func restoreIfNeeded() {
        guard !didRestore, service.availability == .configured else { return }
        didRestore = true
        run(intent: .restore) { service, progress in
            if let profile = try await service.restoreSession(progress: progress) {
                return .signedIn(profile)
            }
            return .signedOut(notice: nil)
        }
    }

    func signIn() {
        guard service.availability == .configured else {
            state = .unconfigured
            return
        }
        run(intent: .signIn) { service, progress in
            .signedIn(try await service.signIn(progress: progress))
        }
    }

    func retry() {
        switch retryIntent {
        case .profile:
            run(intent: .profile) { service, _ in .signedIn(try await service.retryProfile()) }
        case .restore:
            run(intent: .restore) { service, progress in
                if let profile = try await service.restoreSession(progress: progress) { return .signedIn(profile) }
                return .signedOut(notice: nil)
            }
        case .signIn, .none:
            signIn()
        }
    }

    func requestSignOut() {
        guard case .signedIn = state else { return }
        isShowingSignOutConfirmation = true
    }

    func cancelSignOut() {
        isShowingSignOutConfirmation = false
    }

    func confirmSignOut() {
        guard case let .signedIn(profile) = state else { return }
        isShowingSignOutConfirmation = false
        operationTask?.cancel()
        let id = UUID()
        operationID = id
        state = .signingOut(profile)
        operationTask = Task { [weak self] in
            guard let self else { return }
            let result = await service.signOut()
            guard !Task.isCancelled, operationID == id else { return }
            if result.localSessionRemoved {
                state = .signedOut(notice: result.remoteRevocationFailed ? "已在本机退出" : "已退出登录")
            } else {
                state = .retryableFailure(AuthenticationFailure(message: "退出失败，请重试", retryIntent: nil))
            }
        }
    }

    func cancel() {
        operationTask?.cancel()
        operationTask = nil
        Task { await service.cancel() }
    }

    private func run(
        intent: RetryIntent,
        operation: @escaping @MainActor @Sendable (
            any AuthenticationServicing,
            @escaping @MainActor @Sendable (AuthenticationProgress) -> Void
        ) async throws -> AuthenticationState
    ) {
        operationTask?.cancel()
        let id = UUID()
        operationID = id
        retryIntent = intent
        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await operation(service) { [weak self] progress in
                    guard let self, operationID == id else { return }
                    state = Self.state(for: progress)
                }
                guard !Task.isCancelled, operationID == id else { return }
                state = result
                retryIntent = nil
            } catch {
                guard !Task.isCancelled, operationID == id else { return }
                map(error, intent: intent)
            }
        }
    }

    private func map(_ error: Error, intent: RetryIntent) {
        let authError = error as? AuthenticationError ?? .serviceFailure
        switch authError {
        case .configurationUnavailable:
            state = .unconfigured
            retryIntent = nil
        case .userCancelled:
            state = .signedOut(notice: authError.displayMessage)
            retryIntent = nil
        case .authorizationDenied:
            state = .signedOut(notice: authError.displayMessage)
            retryIntent = .signIn
        case .invalidCallback, .missingState, .stateMismatch, .duplicateCallbackParameter,
             .callbackAlreadyConsumed, .missingAuthorizationCode, .transactionExpired:
            state = .invalidCallback(message: authError.displayMessage)
            retryIntent = .signIn
        case .invalidSession, .refreshFailure:
            state = .sessionExpired(message: authError.displayMessage)
            retryIntent = .signIn
        case .profileFailure:
            retryIntent = .profile
            state = .retryableFailure(AuthenticationFailure(message: authError.displayMessage, retryIntent: .profile))
        default:
            retryIntent = intent
            state = .retryableFailure(AuthenticationFailure(message: authError.displayMessage, retryIntent: intent))
        }
    }

    private static func state(for progress: AuthenticationProgress) -> AuthenticationState {
        switch progress {
        case .preparingAuthorization: return .preparingAuthorization
        case .authorizing: return .authorizing
        case .processingCallback: return .processingCallback
        case .loadingProfile: return .loadingProfile
        case .restoring: return .restoring
        }
    }
}
