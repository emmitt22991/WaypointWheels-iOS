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
    private let decoder: JSONDecoder

    init(session: URLSession = .shared,
         bundle: Bundle = .main,
         decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.bundle = bundle
        self.decoder = decoder
    }

    func request<T: Decodable>(path: String) async throws -> T {
        let url = try url(for: path)
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }

        return try decoder.decode(T.self, from: data)
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
}
