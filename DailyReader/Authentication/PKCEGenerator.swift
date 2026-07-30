import CryptoKit
import Foundation
import Security

struct PKCEPair: Equatable, Sendable {
    let verifier: String
    let challenge: String
}

protocol SecureRandomGenerating: Sendable {
    func bytes(count: Int) throws -> [UInt8]
}

struct SystemSecureRandomGenerator: SecureRandomGenerating {
    func bytes(count: Int) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: count)
        guard SecRandomCopyBytes(kSecRandomDefault, count, &bytes) == errSecSuccess else {
            throw AuthenticationError.serviceFailure
        }
        return bytes
    }
}

protocol PKCEGenerating: Sendable {
    func generateState() throws -> String
    func generatePair() throws -> PKCEPair
}

struct SystemPKCEGenerator: PKCEGenerating {
    let random: any SecureRandomGenerating

    init(random: any SecureRandomGenerating = SystemSecureRandomGenerator()) {
        self.random = random
    }

    func generateState() throws -> String {
        Self.base64URL(Data(try random.bytes(count: 32)))
    }

    func generatePair() throws -> PKCEPair {
        let verifier = Self.base64URL(Data(try random.bytes(count: 64)))
        guard (43...128).contains(verifier.count) else {
            throw AuthenticationError.serviceFailure
        }
        return PKCEPair(verifier: verifier, challenge: Self.challenge(for: verifier))
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
