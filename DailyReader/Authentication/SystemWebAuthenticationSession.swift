import AuthenticationServices
import Foundation
import UIKit

protocol WebAuthenticationSession: Sendable {
    func start(authorizationURL: URL, callbackScheme: String, prefersEphemeral: Bool) async throws -> URL
    func cancel() async
}

@MainActor
final class WebAuthenticationPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

actor SystemWebAuthenticationSession: WebAuthenticationSession {
    private var activeSession: ASWebAuthenticationSession?
    private var presentationContext: WebAuthenticationPresentationContext?

    func start(authorizationURL: URL, callbackScheme: String, prefersEphemeral: Bool) async throws -> URL {
        guard activeSession == nil else { throw AuthenticationError.operationAlreadyInProgress }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                Task { @MainActor [self] in
                    let context = WebAuthenticationPresentationContext()
                    let session = ASWebAuthenticationSession(
                        url: authorizationURL,
                        callbackURLScheme: callbackScheme
                    ) { [weak self] callbackURL, error in
                        Task {
                            await self?.clearSession()
                            if let authError = error as? ASWebAuthenticationSessionError,
                               authError.code == .canceledLogin {
                                continuation.resume(throwing: AuthenticationError.userCancelled)
                            } else if error != nil {
                                continuation.resume(throwing: AuthenticationError.transportFailure)
                            } else if let callbackURL {
                                continuation.resume(returning: callbackURL)
                            } else {
                                continuation.resume(throwing: AuthenticationError.invalidCallback)
                            }
                        }
                    }
                    session.presentationContextProvider = context
                    session.prefersEphemeralWebBrowserSession = prefersEphemeral
                    await self.retain(session, context: context)
                    guard session.start() else {
                        await self.clearSession()
                        continuation.resume(throwing: AuthenticationError.transportFailure)
                        return
                    }
                }
            }
        } onCancel: {
            Task { await self.cancel() }
        }
    }

    func cancel() async {
        let session = activeSession
        activeSession = nil
        presentationContext = nil
        await MainActor.run { session?.cancel() }
    }

    private func retain(_ session: ASWebAuthenticationSession, context: WebAuthenticationPresentationContext) {
        activeSession = session
        presentationContext = context
    }

    private func clearSession() {
        activeSession = nil
        presentationContext = nil
    }
}
