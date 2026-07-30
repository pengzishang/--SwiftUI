import Foundation

struct Endpoint<Response: Decodable> {
    let baseURL: URL
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?
    let cachePolicy: URLRequest.CachePolicy

    init(
        baseURL: URL,
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.baseURL = baseURL
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.cachePolicy = cachePolicy
    }

    init(
        absoluteURL: URL,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy
    ) {
        self.init(
            baseURL: absoluteURL,
            path: "",
            method: method,
            queryItems: queryItems,
            headers: headers,
            body: body,
            cachePolicy: cachePolicy
        )
    }

    func urlRequest(timeoutInterval: TimeInterval) throws -> URLRequest {
        guard var components = URLComponents(
            url: resolvedURL,
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }

        if !queryItems.isEmpty {
            components.queryItems = (components.queryItems ?? []) + queryItems
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeoutInterval
        )
        request.httpMethod = method.rawValue
        request.httpBody = body
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        return request
    }

    private var resolvedURL: URL {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else {
            return baseURL
        }
        return baseURL.appendingPathComponent(normalizedPath)
    }
}
