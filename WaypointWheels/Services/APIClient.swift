import Foundation

final class APIClient {
    enum APIError: LocalizedError {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Missing API base URL configuration."
            case let .invalidBaseURL(value):
                return "Invalid API base URL: \(value)."
            case .invalidResponse:
                return "Unexpected response from the server."
            }
        }
    }

    private let session: URLSession
    private let bundle: Bundle
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(session: URLSession = .shared,
         bundle: Bundle = .main,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.bundle = bundle
        self.encoder = encoder
        self.decoder = decoder
    }

    func request<T: Decodable>(path: String) async throws -> T {
        let url = try url(for: path)
        let request = URLRequest(url: url)
        return try await perform(request: request)
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        let url = try url(for: "login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = LoginRequest(email: email, password: password)
        request.httpBody = try encoder.encode(body)

        return try await perform(request: request)
    }

    func url(for path: String) throws -> URL {
        let baseURL = try readBaseURL()
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !trimmedPath.isEmpty else {
            guard let url = components.url else {
                throw APIError.invalidBaseURL(baseURL.absoluteString)
            }
            return url
        }

        if components.path.isEmpty {
            components.path = "/" + trimmedPath
        } else if components.path.hasSuffix("/") {
            components.path += trimmedPath
        } else {
            components.path += "/" + trimmedPath
        }

        guard let url = components.url else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        return url
    }

    private func readBaseURL() throws -> URL {
        guard let value = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !value.isEmpty else {
            throw APIError.missingConfiguration
        }

        guard let url = URL(string: value) else {
            throw APIError.invalidBaseURL(value)
        }

        return url
    }

    private func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
    }
}

extension APIClient {
    struct LoginResponse: Decodable {
        struct User: Decodable {
            let name: String
        }

        let token: String
        let user: User
    }

    private struct LoginRequest: Encodable {
        let email: String
        let password: String
    }
}
