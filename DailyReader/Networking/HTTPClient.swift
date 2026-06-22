import Alamofire
import Foundation

final class HTTPClient {
    static let browserUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    private let baseURL: URL
    private let afSession: Session
    private let decoder: JSONDecoder
    private let timeoutInterval: TimeInterval

    init(
        baseURL: URL = URL(string: "https://news-at.zhihu.com/api/4")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        timeoutInterval: TimeInterval = 15
    ) {
        self.baseURL = baseURL
        self.decoder = decoder
        self.timeoutInterval = timeoutInterval

        let configuration = session.configuration
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        
        let interceptor = HTTPClientInterceptor()
        self.afSession = Session(configuration: configuration, interceptor: interceptor)
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !normalizedPath.isEmpty else {
            throw APIError.invalidURL
        }
        let url = baseURL.appendingPathComponent(normalizedPath)

        do {
            let value = try await afSession.request(url)
                .validate(statusCode: 200..<300)
                .serializingDecodable(T.self, decoder: decoder)
                .value
            return value
        } catch {
            throw mapError(error)
        }
    }

    private func mapError(_ error: Error) -> APIError {
        if let afError = error as? AFError {
            switch afError {
            case .responseValidationFailed(let reason):
                switch reason {
                case .unacceptableStatusCode(let code):
                    return .httpStatus(code)
                default:
                    return .invalidResponse
                }
            case .responseSerializationFailed(let reason):
                switch reason {
                case .decodingFailed:
                    return .decodingFailed
                default:
                    return .invalidResponse
                }
            case .sessionTaskFailed(let underlyingError):
                if let apiError = underlyingError as? APIError {
                    return apiError
                }
                return .transport(underlyingError.localizedDescription)
            default:
                return .transport(afError.localizedDescription)
            }
        } else if let apiError = error as? APIError {
            return apiError
        } else {
            return .transport(error.localizedDescription)
        }
    }
}

final class HTTPClientInterceptor: RequestInterceptor {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var request = urlRequest
        if request.httpMethod?.uppercased() == "GET" {
            request.setValue(HTTPClient.browserUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }
        completion(.success(request))
    }
}

