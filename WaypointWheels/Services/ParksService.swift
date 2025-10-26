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
        let urlString = "\(baseURL)/parks/ratings.php"
        guard let url = URL(string: urlString) else {
            throw ParksServiceError.invalidURL
        }
        
        let payload: [String: Any] = [
            "park_id": parkID.uuidString,
            "rating": rating,
            "contact_id": 1 // TODO: Get from authentication
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw ParksServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
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
            
            let park = try decoder.decode(Park.self, from: data)
            return park
            
        } catch let error as ParksServiceError {
            throw error
        } catch {
            throw ParksServiceError.networkError(error)
        }
    }
    
    func submitReview(parkID: UUID, rating: Double, comment: String) async throws -> ParkDetail.Review {
        let urlString = "\(baseURL)/parks/reviews.php"
        guard let url = URL(string: urlString) else {
            throw ParksServiceError.invalidURL
        }
        
        let payload: [String: Any] = [
            "park_id": parkID.uuidString,
            "rating": rating,
            "comment": comment,
            "contact_id": 1 // TODO: Get from authentication
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw ParksServiceError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ParksServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ParksServiceError.serverError(errorResponse.message ?? errorResponse.error)
                }
                throw ParksServiceError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            
            let review = try decoder.decode(ParkDetail.Review.self, from: data)
            return review
            
        } catch let error as ParksServiceError {
            throw error
        } catch {
            throw ParksServiceError.networkError(error)
        }
    }
    
    func uploadPhoto(parkID: UUID, data: Data, filename: String, caption: String?) async throws -> ParkDetail.Photo {
        let urlString = "\(baseURL)/parks/photos.php"
        guard let url = URL(string: urlString) else {
            throw ParksServiceError.invalidURL
        }
        
        // Create multipart form data
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        
        // Add park_id
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"park_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(parkID.uuidString)\r\n".data(using: .utf8)!)
        
        // Add caption if provided
        if let caption = caption, !caption.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)
        }
        
        // Add photo data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        
        do {
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ParksServiceError.invalidResponse
            }
            
            guard httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: responseData) {
                    throw ParksServiceError.serverError(errorResponse.message ?? errorResponse.error)
                }
                throw ParksServiceError.serverError("HTTP \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            
            let photo = try decoder.decode(ParkDetail.Photo.self, from: responseData)
            return photo
            
        } catch let error as ParksServiceError {
            throw error
        } catch {
            throw ParksServiceError.networkError(error)
        }
    }
}

private struct ErrorResponse: Codable {
    let error: String
    let message: String?
}
