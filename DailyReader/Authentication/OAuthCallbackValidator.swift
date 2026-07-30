import Foundation

protocol OAuthCallbackValidating: Sendable {
    func validate(
        callbackURL: URL,
        transaction: inout AuthorizationTransaction,
        configuration: OAuthConfiguration,
        now: Date
    ) throws -> ValidatedAuthorizationCode
}

struct OAuthCallbackValidator: OAuthCallbackValidating {
    let transactionLifetime: TimeInterval

    init(transactionLifetime: TimeInterval = 300) {
        self.transactionLifetime = transactionLifetime
    }

    func validate(
        callbackURL: URL,
        transaction: inout AuthorizationTransaction,
        configuration: OAuthConfiguration,
        now: Date = Date()
    ) throws -> ValidatedAuthorizationCode {
        guard !transaction.callbackConsumed else { throw AuthenticationError.callbackAlreadyConsumed }
        transaction.callbackConsumed = true
        guard now.timeIntervalSince(transaction.createdAt) <= transactionLifetime else {
            throw AuthenticationError.transactionExpired
        }
        guard exactRedirect(callbackURL, matches: configuration.redirectURI),
              callbackURL.user == nil, callbackURL.password == nil, callbackURL.fragment == nil else {
            throw AuthenticationError.invalidCallback
        }
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw AuthenticationError.invalidCallback
        }
        let grouped = Dictionary(grouping: components.queryItems ?? [], by: \.name)
        for key in ["code", "state", "error"] where (grouped[key]?.count ?? 0) > 1 {
            throw AuthenticationError.duplicateCallbackParameter
        }
        if grouped["code"] != nil, grouped["error"] != nil {
            throw AuthenticationError.invalidCallback
        }
        guard let state = grouped["state"]?.first?.value, !state.isEmpty else {
            throw AuthenticationError.missingState
        }
        guard constantTimeEqual(state, transaction.state) else {
            throw AuthenticationError.stateMismatch
        }
        if grouped["error"]?.first?.value != nil {
            throw AuthenticationError.authorizationDenied
        }
        guard let code = grouped["code"]?.first?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty else {
            throw AuthenticationError.missingAuthorizationCode
        }
        return ValidatedAuthorizationCode(value: code)
    }

    private func exactRedirect(_ callback: URL, matches redirect: URL) -> Bool {
        callback.scheme?.lowercased() == redirect.scheme?.lowercased()
            && callback.host?.lowercased() == redirect.host?.lowercased()
            && effectivePort(callback) == effectivePort(redirect)
            && callback.path == redirect.path
    }

    private func effectivePort(_ url: URL) -> Int? {
        if let port = url.port { return port }
        return url.scheme?.lowercased() == "https" ? 443 : nil
    }

    private func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        var difference = UInt8(left.count == right.count ? 0 : 1)
        let count = max(left.count, right.count)
        for index in 0..<count {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0
            difference |= a ^ b
        }
        return difference == 0
    }
}
