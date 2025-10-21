import Foundation

enum ParksServiceError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}



@MainActor
final class ParksService {
    private let baseURL: String
    
    init(baseURL: String = "https://waypointwheels.com/api") {
        self.baseURL = baseURL
    }
    
    func fetchParks() async throws -> [Park] {
        let urlString = "\(baseURL)/parks/"
        guard let url = URL(string: urlString) else {
            throw ParksServiceError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ParksServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ParksServiceError.serverError(errorResponse.message ?? errorResponse.error)
                }
                throw ParksServiceError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let parks = try decoder.decode([Park].self, from: data)
            return parks
            
        } catch let error as ParksServiceError {
            throw error
        } catch {
            throw ParksServiceError.networkError(error)
        }
    }
    
    func fetchParkDetail(parkID: UUID) async throws -> ParkDetail {
        let urlString = "\(baseURL)/parks/index.php?id=\(parkID.uuidString)"
        guard let url = URL(string: urlString) else {
            throw ParksServiceError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ParksServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ParksServiceError.serverError(errorResponse.message ?? errorResponse.error)
                }
                throw ParksServiceError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            let detail = try decoder.decode(ParkDetail.self, from: data)
            return detail
            
        } catch let error as ParksServiceError {
            throw error
        } catch let error as DecodingError {
            throw ParksServiceError.decodingError(error)
        } catch {
            throw ParksServiceError.networkError(error)
        }
    }
    
    func submitRating(parkID: UUID, rating: Double) async throws -> Park {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock updated park
        return Park(
            id: parkID,
            name: "Mock Park",
            state: "CA",
            city: "Test City",
            familyRating: rating,
            communityRating: rating,
            familyReviewCount: 1,
            communityReviewCount: 1,
            description: "",
            memberships: [],
            amenities: [],
            featuredNotes: []
        )
    }
    
    func submitReview(parkID: UUID, rating: Double, comment: String) async throws -> ParkDetail.Review {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock review
        return ParkDetail.Review(
            id: UUID(),
            authorName: "You",
            rating: rating,
            comment: comment,
            createdAt: Date(),
            isFamilyReview: true
        )
    }
    
    func uploadPhoto(parkID: UUID, data: Data, filename: String, caption: String?) async throws -> ParkDetail.Photo {
        // TODO: Implement actual API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Return mock photo
        return ParkDetail.Photo(
            id: UUID(),
            imageURL: URL(string: "https://via.placeholder.com/300")!,
            caption: caption,
            uploadedBy: "You",
            isFamilyPhoto: true
        )
    }
}

private struct ErrorResponse: Codable {
    let error: String
    let message: String?
}
