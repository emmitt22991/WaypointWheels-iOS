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

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case patch = "PATCH"
        case delete = "DELETE"
    }

    private let session: URLSession
    private let bundle: Bundle
    private let explicitBaseURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let keychainStore: (any KeychainStoring)?

    init(session: URLSession = .shared,
         bundle: Bundle = .main,
         baseURL: URL? = nil,
         encoder: JSONEncoder = JSONEncoder(),
         decoder: JSONDecoder = JSONDecoder(),
         keychainStore: (any KeychainStoring)? = KeychainStore()) {
        self.session = session
        self.bundle = bundle
        self.explicitBaseURL = baseURL
        self.encoder = encoder
        self.decoder = decoder
        self.keychainStore = keychainStore
    }

    func request<T: Decodable>(path: String) async throws -> T {
        try await request(path: path, method: .get)
    }

    func request<T: Decodable>(path: String, method: HTTPMethod, additionalHeaders: [String: String] = [:]) async throws -> T {
        let request = try makeRequest(path: path, method: method, additionalHeaders: additionalHeaders)
        return try await perform(request: request)
    }

    func request<T: Decodable, Body: Encodable>(path: String,
                                                method: HTTPMethod,
                                                body: Body,
                                                additionalHeaders: [String: String] = [:]) async throws -> T {
        var request = try makeRequest(path: path, method: method, additionalHeaders: additionalHeaders)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request: request)
    }

    func request<T: Decodable>(path: String,
                               method: HTTPMethod,
                               bodyData: Data,
                               contentType: String,
                               additionalHeaders: [String: String] = [:]) async throws -> T {
        var request = try makeRequest(path: path, method: method, additionalHeaders: additionalHeaders)
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        return try await perform(request: request)
    }

    func request<T: Decodable, Body: Encodable>(path: String,
                                                method: String,
                                                body: Body? = nil,
                                                additionalHeaders: [String: String] = [:]) async throws -> T {
        let url = try url(for: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        applyAuthorization(to: &request)
        return try await perform(request: request)
    }

    func request(path: String,
                 method: String,
                 additionalHeaders: [String: String] = [:]) async throws -> APIResponse<Data> {
        let url = try url(for: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        additionalHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        applyAuthorization(to: &request)
        return try await performResponse(request: request)
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

        var sanitizedPath = path.drop(while: { $0 == "/" })
        var hasTrailingSlash = false

        while sanitizedPath.last == "/" {
            hasTrailingSlash = true
            sanitizedPath = sanitizedPath.dropLast()
        }

        let cleanedPath = String(sanitizedPath)

        guard !cleanedPath.isEmpty else {
            guard var url = components.url else {
                throw APIError.invalidBaseURL(baseURL.absoluteString)
            }

            if hasTrailingSlash {
                url.appendPathComponent("")
            }

            return url
        }

        if components.path.isEmpty || components.path == "/" {
            components.path = "/" + cleanedPath
        } else if components.path.hasSuffix("/") {
            components.path += cleanedPath
        } else {
            components.path += "/" + cleanedPath
        }

        if hasTrailingSlash {
            components.path += "/"
        }

        guard let url = components.url else {
            throw APIError.invalidBaseURL(baseURL.absoluteString)
        }

        // DEBUG: Print the final URL
        print("🌐 API Request URL: \(url.absoluteString)")

        return url
    }

    private func makeRequest(path: String,
                              method: HTTPMethod,
                              additionalHeaders: [String: String]) throws -> URLRequest {
        let url = try url(for: path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        applyAuthorization(to: &request)
        return request
    }

    private func requireBaseURL() throws -> URL {
        if let explicitBaseURL {
            return explicitBaseURL
        }

        guard let value = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !value.isEmpty else {
            throw APIError.missingConfiguration
        }

        guard let url = URL(string: value) else {
            throw APIError.invalidBaseURL(value)
        }

        return url
    }

    func perform<T: Decodable>(request: URLRequest) async throws -> T {
        try await performResponse(request: request).value
    }

    func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }

    private func performResponse<T: Decodable>(request: URLRequest) async throws -> APIResponse<T> {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if [401, 403].contains(httpResponse.statusCode) {
                handleUnauthorizedResponse()
            }
            let rawBody: String? = {
                guard !data.isEmpty else { return nil }
                let decoded = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }()
            if let message = decodeErrorMessage(from: data), !message.isEmpty {
                throw APIError.serverError(message: message, body: rawBody)
            }

            if let rawBody = rawBody, !rawBody.isEmpty {
                throw APIError.serverError(message: rawBody, body: rawBody)
            }

            throw APIError.invalidResponse
        }

        if data.isEmpty, let emptyType = T.self as? EmptyDecodable.Type {
            return APIResponse(value: emptyType.init() as! T, data: data)
        }

        if T.self == Data.self, let cast = data as? T {
            return APIResponse(value: cast, data: data)
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
        guard let token = ((try? keychainStore.fetchToken()) ?? nil),
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

    private func handleUnauthorizedResponse() {
        // Previously, unauthorized responses immediately cleared any stored
        // credentials and forced the session to sign out. This caused the app
        // to bounce users back to the sign-in screen whenever an authenticated
        // request failed, even after a successful login. To honor the new
        // requirement that once a user signs in they should remain in the
        // authenticated experience, we intentionally avoid mutating persisted
        // credentials or broadcasting a session-expiration notification here.
        //
        // Individual features can surface the underlying error to the user and
        // offer recovery, but the global session state remains intact.
    }
}

extension APIClient {
    struct APIResponse<T> {
        let value: T
        let data: Data

        var rawString: String? {
            guard !data.isEmpty else { return nil }
            let decoded = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let trimmed = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
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

protocol EmptyDecodable {
    init()
}
