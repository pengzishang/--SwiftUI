protocol HTTPClientProtocol {
    func execute<Response: Decodable>(_ endpoint: Endpoint<Response>) async throws -> Response
}
