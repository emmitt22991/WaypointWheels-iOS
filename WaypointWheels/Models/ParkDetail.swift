import Foundation

struct ParkDetail: Decodable {
    struct Photo: Identifiable, Decodable, Hashable {
        let id: UUID
        let imageURL: URL
        let caption: String?
        let uploadedBy: String?

        private enum CodingKeys: String, CodingKey {
            case id
            case imageURL = "url"
            case caption
            case uploadedBy = "uploaded_by"
        }
    }

    struct Review: Identifiable, Decodable, Hashable {
        let id: UUID
        let authorName: String
        let rating: Double
        let comment: String
        let createdAt: Date

        private enum CodingKeys: String, CodingKey {
            case id
            case authorName = "author_name"
            case rating
            case comment
            case createdAt = "created_at"
        }

        init(id: UUID, authorName: String, rating: Double, comment: String, createdAt: Date) {
            self.id = id
            self.authorName = authorName
            self.rating = rating
            self.comment = comment
            self.createdAt = createdAt
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            authorName = try container.decode(String.self, forKey: .authorName)
            rating = try container.decode(Double.self, forKey: .rating)
            comment = try container.decode(String.self, forKey: .comment)
            let dateString = try container.decode(String.self, forKey: .createdAt)
            createdAt = ISO8601DateFormatter.cachedFormatter.date(from: dateString) ?? Date()
        }

        var formattedDate: String {
            DateFormatter.cachedMediumFormatter.string(from: createdAt)
        }
    }

    let summary: Park
    let photos: [Photo]
    let amenities: [Park.Amenity]
    let notes: [String]
    let reviews: [Review]
    let userRating: Double?
    let userReview: Review?

    private enum CodingKeys: String, CodingKey {
        case summary = "park"
        case photos
        case amenities
        case notes
        case reviews
        case userRating = "user_rating"
        case userReview = "user_review"
    }
}

private extension ISO8601DateFormatter {
    static let cachedFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private extension DateFormatter {
    static let cachedMediumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
