import Foundation

final class TripsService {
    enum TripsError: LocalizedError, Equatable {
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
                return "Unexpected response from the trips endpoint."
            case let .serverError(message):
                return message
            }
        }
    }

    struct ItineraryResponse: Decodable {
        let legs: [TripLeg]
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchCurrentItinerary() async throws -> [TripLeg] {
        do {
            let response: ItineraryResponse = try await apiClient.request(path: "trips/current")
            return response.legs
        } catch let error as APIClient.APIError {
            throw TripsError(apiError: error)
        }
    }
}

private extension TripsService.TripsError {
    init(apiError: APIClient.APIError) {
        switch apiError {
        case .missingConfiguration:
            self = .missingConfiguration
        case let .invalidBaseURL(value):
            self = .invalidBaseURL(value)
        case .invalidResponse:
            self = .invalidResponse
        case let .serverError(message, _):
            self = .serverError(message)
        }
    }
}
