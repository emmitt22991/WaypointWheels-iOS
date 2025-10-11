import Foundation

final class HealthService {
    enum HealthError: LocalizedError {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Missing API base URL configuration."
            case let .invalidBaseURL(value):
                return "Invalid API base URL: \(value)."
            case .invalidResponse:
                return "Unexpected response from the health endpoint."
            case let .serverError(message):
                return message
            }
        }
    }

    struct HealthResponse: Decodable {
        let status: String
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchHealthStatus() async throws -> String {
        do {
            let response: HealthResponse = try await apiClient.request(path: "health")
            return response.status
        } catch let error as APIClient.APIError {
            throw HealthError(apiError: error)
        }
    }

    func healthURL(from baseURLString: String) throws -> URL {
        guard let baseURL = URL(string: baseURLString) else {
            throw HealthError.invalidBaseURL(baseURLString)
        }

        return baseURL.appendingPathComponent("health")
    }
}

private extension HealthService.HealthError {
    init(apiError: APIClient.APIError) {
        switch apiError {
        case .missingConfiguration:
            self = .missingConfiguration
        case let .invalidBaseURL(value):
            self = .invalidBaseURL(value)
        case .invalidResponse:
            self = .invalidResponse
        case let .serverError(message):
            self = .serverError(message)
        }
    }
}
