import Foundation

final class ParksService {
    enum ParksServiceError: LocalizedError, Equatable {
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
                return "Unexpected response from the parks endpoint."
            case let .serverError(message):
                return message
            }
        }
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchParkDetail(parkID: UUID) async throws -> ParkDetail {
        do {
            return try await apiClient.request(path: "api/parks/\(parkID.uuidString)")
        } catch let error as APIClient.APIError {
            throw ParksServiceError(apiError: error)
        }
    }

    func submitRating(parkID: UUID, rating: Double) async throws -> Park {
        let request = RatingRequest(rating: rating)
        do {
            return try await apiClient.request(path: "api/parks/\(parkID.uuidString)/rating",
                                               method: .put,
                                               body: request)
        } catch let error as APIClient.APIError {
            throw ParksServiceError(apiError: error)
        }
    }

    func submitReview(parkID: UUID, rating: Double, comment: String) async throws -> ParkDetail.Review {
        let request = ReviewRequest(rating: rating, comment: comment)
        do {
            return try await apiClient.request(path: "api/parks/\(parkID.uuidString)/reviews",
                                               method: .post,
                                               body: request)
        } catch let error as APIClient.APIError {
            throw ParksServiceError(apiError: error)
        }
    }

    func uploadPhoto(parkID: UUID, data: Data, filename: String, caption: String?) async throws -> ParkDetail.Photo {
        let request = UploadPhotoRequest(data: data.base64EncodedString(), filename: filename, caption: caption)
        do {
            return try await apiClient.request(path: "api/parks/\(parkID.uuidString)/photos",
                                               method: .post,
                                               body: request)
        } catch let error as APIClient.APIError {
            throw ParksServiceError(apiError: error)
        }
    }
}

private extension ParksService.ParksServiceError {
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

private extension ParksService {
    struct RatingRequest: Encodable {
        let rating: Double
    }

    struct ReviewRequest: Encodable {
        let rating: Double
        let comment: String
    }

    struct UploadPhotoRequest: Encodable {
        let data: String
        let filename: String
        let caption: String?
    }
}
