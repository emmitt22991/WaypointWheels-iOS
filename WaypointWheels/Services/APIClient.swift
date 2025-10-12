import Foundation

final class APIClient {
    enum APIError: LocalizedError {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse
        case serverError(message: String, body: String?)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Missing API base URL configuration."
            case let .invalidBaseURL(value):
                return "Invalid API base URL: \(value)."
            case .invalidResponse:
                return "Unexpected response from the server."
            case let .serverError(message, _):
                return message
            }
        }
    }

    private let session: URLSession
    private let bundle: Bundle
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let keychainStore: (any KeychainStoring)?

    init(session: URLSession = .shared,
         bundle: Bundle = .main,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder(),
         keychainStore: (any KeychainStoring)? = KeychainStore()) {
        self.session = session
        self.bundle = bundle
        self.encoder = encoder
        self.decoder = decoder
        self.keychainStore = keychainStore
    }

    func request<T: Decodable>(path: String) async throws -> T {
        let url = try url(for: path)
        var request = URLRequest(url: url)
        applyAuthorization(to: &request)
        return try await perform(request: request)
    }

    func request<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let baseURL = try url(for: path)
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        let filteredItems = queryItems.filter { item in
            guard let value = item.value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if !filteredItems.isEmpty {
            components.queryItems = filteredItems
        }

        guard let url = components.url else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        var request = URLRequest(url: url)
        applyAuthorization(to: &request)
        return try await perform(request: request)
    }

    func login(email: String, password: String) async throws -> APIResponse<LoginResponse> {
        let base = try requireBaseURL()
        let url = base
            .appendingPathComponent("login")
            .appendingPathComponent("")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = LoginRequest(email: email, password: password)
        request.httpBody = try encoder.encode(body)

        return try await performResponse(request: request)
    }

    func url(for path: String) throws -> URL {
        let baseURL = try requireBaseURL()
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

    private func requireBaseURL() throws -> URL {
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
        try await performResponse(request: request).value
    }

    private func performResponse<T: Decodable>(request: URLRequest) async throws -> APIResponse<T> {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let message = decodeErrorMessage(from: data), !message.isEmpty {
                throw APIError.serverError(message: message, body: rawBody)
            }

            if let rawBody = rawBody, !rawBody.isEmpty {
                throw APIError.serverError(message: rawBody, body: rawBody)
            }

            throw APIError.invalidResponse
        }

        let decoded = try decoder.decode(T.self, from: data)
        return APIResponse(value: decoded, data: data)
    }

    private func applyAuthorization(to request: inout URLRequest) {
        guard let token = authorizationToken() else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }

    private func authorizationToken() -> String? {
        guard let keychainStore = keychainStore else { return nil }
        guard let storedToken = try? keychainStore.fetchToken(),
              let token = storedToken,
              !token.isEmpty else { return nil }
        return token
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = self.decoder.keyDecodingStrategy
        decoder.dateDecodingStrategy = self.decoder.dateDecodingStrategy
        decoder.dataDecodingStrategy = self.decoder.dataDecodingStrategy
        decoder.nonConformingFloatDecodingStrategy = self.decoder.nonConformingFloatDecodingStrategy

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            if let message = envelope.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                return message
            }

            if let message = envelope.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                return message
            }

            if let first = envelope.errors?.compactMap({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
                return first
            }
        }

        return nil
    }
}

extension APIClient {
    struct APIResponse<T> {
        let value: T
        let data: Data

        var rawString: String? {
            guard !data.isEmpty else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }

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

    private struct ErrorEnvelope: Decodable {
        struct ErrorMessage: Decodable {
            let message: String?
        }

        let message: String?
        let error: ErrorMessage?
        let errors: [String]?
    }
}
