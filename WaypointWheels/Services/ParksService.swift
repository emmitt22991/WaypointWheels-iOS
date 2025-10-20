import Foundation

final class ParksService {
    enum ParksServiceError: LocalizedError, Equatable {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse
        case serverError(String)
        case decodingError(String)

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
            case let .decodingError(details):
                return "Failed to decode parks data: \(details)"
            }
        }
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchParks() async throws -> [Park] {
        print("🌐 ParksService: Starting to fetch parks...")
        
        do {
            let parks: [Park] = try await apiClient.request(path: "../api/parks.php")
            
            print("✅ ParksService: Successfully fetched \(parks.count) parks")
            
            if let firstPark = parks.first {
                print("📍 Sample park: \(firstPark.name) in \(firstPark.city), \(firstPark.state)")
                print("   Rating: \(firstPark.familyRating)")
                print("   Memberships: \(firstPark.memberships.map { $0.rawValue }.joined(separator: ", "))")
            }
            
            return parks
            
        } catch let error as APIClient.APIError {
            print("❌ ParksService: API error occurred")
            print("   Error type: \(error)")
            print("   Description: \(error.localizedDescription)")
            
            throw ParksServiceError(apiError: error)
            
        } catch let decodingError as DecodingError {
            print("❌ ParksService: Decoding error occurred")
            
            let errorDetails = formatDecodingError(decodingError)
            print("   Details: \(errorDetails)")
            
            throw ParksServiceError.decodingError(errorDetails)
            
        } catch {
            print("❌ ParksService: Unexpected error occurred")
            print("   Error: \(error)")
            print("   Type: \(type(of: error))")
            
            throw ParksServiceError.serverError(error.localizedDescription)
        }
    }

    func fetchParkDetail(parkID: UUID) async throws -> ParkDetail {
        print("🌐 ParksService: Fetching detail for park \(parkID.uuidString)")
        
        do {
            let detail: ParkDetail = try await apiClient.request(path: "../api/parks/\(parkID.uuidString)")
            
            print("✅ ParksService: Successfully fetched park detail")
            print("   Park: \(detail.summary.name)")
            print("   Photos: \(detail.familyPhotos.count + detail.communityPhotos.count)")
            print("   Reviews: \(detail.familyReviews.count + detail.communityReviews.count)")
            
            return detail
            
        } catch let error as APIClient.APIError {
            print("❌ ParksService: API error fetching park detail")
            print("   Error: \(error.localizedDescription)")
            
            throw ParksServiceError(apiError: error)
            
        } catch let decodingError as DecodingError {
            print("❌ ParksService: Decoding error for park detail")
            
            let errorDetails = formatDecodingError(decodingError)
            print("   Details: \(errorDetails)")
            
            throw ParksServiceError.decodingError(errorDetails)
            
        } catch {
            print("❌ ParksService: Unexpected error fetching park detail")
            print("   Error: \(error)")
            
            throw ParksServiceError.serverError(error.localizedDescription)
        }
    }

    func submitRating(parkID: UUID, rating: Double) async throws -> Park {
        print("🌐 ParksService: Submitting rating \(rating) for park \(parkID.uuidString)")
        
        let request = RatingRequest(rating: rating)
        
        do {
            let updatedPark: Park = try await apiClient.request(
                path: "../api/parks/\(parkID.uuidString)/rating",
                method: .put,
                body: request
            )
            
            print("✅ ParksService: Rating submitted successfully")
            
            return updatedPark
            
        } catch let error as APIClient.APIError {
            print("❌ ParksService: API error submitting rating")
            print("   Error: \(error.localizedDescription)")
            
            throw ParksServiceError(apiError: error)
            
        } catch {
            print("❌ ParksService: Unexpected error submitting rating")
            print("   Error: \(error)")
            
            throw ParksServiceError.serverError(error.localizedDescription)
        }
    }

    func submitReview(parkID: UUID, rating: Double, comment: String) async throws -> ParkDetail.Review {
        print("🌐 ParksService: Submitting review for park \(parkID.uuidString)")
        print("   Rating: \(rating)")
        print("   Comment length: \(comment.count) characters")
        
        let request = ReviewRequest(rating: rating, comment: comment)
        
        do {
            let review: ParkDetail.Review = try await apiClient.request(
                path: "../api/parks/\(parkID.uuidString)/reviews",
                method: .post,
                body: request
            )
            
            print("✅ ParksService: Review submitted successfully")
            
            return review
            
        } catch let error as APIClient.APIError {
            print("❌ ParksService: API error submitting review")
            print("   Error: \(error.localizedDescription)")
            
            throw ParksServiceError(apiError: error)
            
        } catch {
            print("❌ ParksService: Unexpected error submitting review")
            print("   Error: \(error)")
            
            throw ParksServiceError.serverError(error.localizedDescription)
        }
    }

    func uploadPhoto(parkID: UUID, data: Data, filename: String, caption: String?) async throws -> ParkDetail.Photo {
        print("🌐 ParksService: Uploading photo for park \(parkID.uuidString)")
        print("   Filename: \(filename)")
        print("   Data size: \(data.count) bytes")
        print("   Caption: \(caption ?? "none")")
        
        let request = UploadPhotoRequest(
            data: data.base64EncodedString(),
            filename: filename,
            caption: caption
        )
        
        do {
            let photo: ParkDetail.Photo = try await apiClient.request(
                path: "../api/parks/\(parkID.uuidString)/photos",
                method: .post,
                body: request
            )
            
            print("✅ ParksService: Photo uploaded successfully")
            print("   Photo ID: \(photo.id)")
            
            return photo
            
        } catch let error as APIClient.APIError {
            print("❌ ParksService: API error uploading photo")
            print("   Error: \(error.localizedDescription)")
            
            throw ParksServiceError(apiError: error)
            
        } catch {
            print("❌ ParksService: Unexpected error uploading photo")
            print("   Error: \(error)")
            
            throw ParksServiceError.serverError(error.localizedDescription)
        }
    }
    
    private func formatDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")). \(context.debugDescription)"
            
        case .valueNotFound(let type, let context):
            return "Value not found for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")). \(context.debugDescription)"
            
        case .keyNotFound(let key, let context):
            return "Key '\(key.stringValue)' not found at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")). \(context.debugDescription)"
            
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map { $0.stringValue }.joined(separator: " -> ")). \(context.debugDescription)"
            
        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
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
