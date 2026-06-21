import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "接口地址无效"
        case .invalidResponse:
            return "接口响应无效"
        case .httpStatus(let statusCode):
            return "接口请求失败（\(statusCode)）"
        case .decodingFailed:
            return "接口数据解析失败"
        case .transport(let message):
            return message.isEmpty ? "网络连接失败" : message
        }
    }
}
