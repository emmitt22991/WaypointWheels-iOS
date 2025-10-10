import Foundation

final class HealthService {
    enum HealthError: LocalizedError {
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
                return "Unexpected response from the health endpoint."
            }
        }
    }

    struct HealthResponse: Decodable {
        let status: String
    }

    private let session: URLSession
    private let bundle: Bundle

    init(session: URLSession = .shared, bundle: Bundle = .main) {
        self.session = session
        self.bundle = bundle
    }

    func fetchHealthStatus() async throws -> String {
        let baseURLString = try readBaseURLString()
        let healthURL = try healthURL(from: baseURLString)

        let (data, response) = try await session.data(from: healthURL)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw HealthError.invalidResponse
        }

        let decoder = JSONDecoder()
        let health = try decoder.decode(HealthResponse.self, from: data)
        return health.status
    }

    func healthURL(from baseURLString: String) throws -> URL {
        guard let baseURL = URL(string: baseURLString) else {
            throw HealthError.invalidBaseURL(baseURLString)
        }

        return baseURL.appendingPathComponent("health")
    }

    private func readBaseURLString() throws -> String {
        guard let value = bundle.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              !value.isEmpty else {
            throw HealthError.missingConfiguration
        }

        return value
    }
}
