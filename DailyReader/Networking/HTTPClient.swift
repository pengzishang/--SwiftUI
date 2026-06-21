import Foundation

final class HTTPClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let timeoutInterval: TimeInterval

    init(
        baseURL: URL = URL(string: "https://news-at.zhihu.com/api/4")!,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        timeoutInterval: TimeInterval = 15
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.timeoutInterval = timeoutInterval
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !normalizedPath.isEmpty else {
            throw APIError.invalidURL
        }
        let url = baseURL.appendingPathComponent(normalizedPath)
        var request = URLRequest(url: url, timeoutInterval: timeoutInterval)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("DailyReaderSwiftUI/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw APIError.httpStatus(httpResponse.statusCode)
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingFailed
            }
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
    }
}
