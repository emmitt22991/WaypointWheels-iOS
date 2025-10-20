import Foundation

struct ParkDetail: Decodable {
    struct Photo: Identifiable, Decodable, Hashable {
        let id: UUID
        let imageURL: URL
        let caption: String?
        let uploadedBy: String?
        let isFamilyPhoto: Bool

        private enum CodingKeys: String, CodingKey {
            case id
            case imageURL = "url"
            case caption
            case uploadedBy = "uploaded_by"
            case isFamilyPhoto = "is_family_photo"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            imageURL = try container.decode(URL.self, forKey: .imageURL)
            caption = try container.decodeIfPresent(String.self, forKey: .caption)
            uploadedBy = try container.decodeIfPresent(String.self, forKey: .uploadedBy)
            isFamilyPhoto = try container.decodeIfPresent(Bool.self, forKey: .isFamilyPhoto) ?? false
        }

        init(id: UUID, imageURL: URL, caption: String?, uploadedBy: String?, isFamilyPhoto: Bool) {
            self.id = id
            self.imageURL = imageURL
            self.caption = caption
            self.uploadedBy = uploadedBy
            self.isFamilyPhoto = isFamilyPhoto
        }
    }

    struct Review: Identifiable, Decodable, Hashable {
        let id: UUID
        let authorName: String
        let rating: Double
        let comment: String
        let createdAt: Date
        let isFamilyReview: Bool

        private enum CodingKeys: String, CodingKey {
            case id
            case authorName = "author_name"
            case rating
            case comment
            case createdAt = "created_at"
            case isFamilyReview = "is_family_review"
        }

        init(id: UUID, authorName: String, rating: Double, comment: String, createdAt: Date, isFamilyReview: Bool) {
            self.id = id
            self.authorName = authorName
            self.rating = rating
            self.comment = comment
            self.createdAt = createdAt
            self.isFamilyReview = isFamilyReview
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            authorName = try container.decode(String.self, forKey: .authorName)
            rating = try container.decode(Double.self, forKey: .rating)
            comment = try container.decode(String.self, forKey: .comment)
            let dateString = try container.decode(String.self, forKey: .createdAt)
            createdAt = ISO8601DateFormatter.cachedFormatter.date(from: dateString) ?? Date()
            isFamilyReview = try container.decodeIfPresent(Bool.self, forKey: .isFamilyReview) ?? false
        }

        var formattedDate: String {
            DateFormatter.cachedMediumFormatter.string(from: createdAt)
        }
    }

    let summary: Park
    let familyPhotos: [Photo]
    let communityPhotos: [Photo]
    let amenities: [Park.Amenity]
    let notes: [String]
    let familyReviews: [Review]
    let communityReviews: [Review]
    let userRating: Double?
    let userReview: Review?

    private enum CodingKeys: String, CodingKey {
        case summary = "park"
        case photos
        case familyPhotos = "family_photos"
        case communityPhotos = "community_photos"
        case amenities
        case notes
        case reviews
        case familyReviews = "family_reviews"
        case communityReviews = "community_reviews"
        case userRating = "user_rating"
        case userReview = "user_review"
    }

    init(summary: Park,
         familyPhotos: [Photo],
         communityPhotos: [Photo],
         amenities: [Park.Amenity],
         notes: [String],
         familyReviews: [Review],
         communityReviews: [Review],
         userRating: Double?,
         userReview: Review?) {
        self.summary = summary
        self.familyPhotos = familyPhotos
        self.communityPhotos = communityPhotos
        self.amenities = amenities
        self.notes = notes
        self.familyReviews = familyReviews
        self.communityReviews = communityReviews
        self.userRating = userRating
        self.userReview = userReview
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decode(Park.self, forKey: .summary)

        let legacyPhotos = try container.decodeIfPresent([Photo].self, forKey: .photos) ?? []
        familyPhotos = try container.decodeIfPresent([Photo].self, forKey: .familyPhotos) ?? legacyPhotos.filter { $0.isFamilyPhoto }
        if let explicitCommunityPhotos = try container.decodeIfPresent([Photo].self, forKey: .communityPhotos) {
            communityPhotos = explicitCommunityPhotos
        } else if familyPhotos.isEmpty {
            communityPhotos = legacyPhotos
        } else {
            communityPhotos = legacyPhotos.filter { !$0.isFamilyPhoto }
        }

        amenities = try container.decode([Park.Amenity].self, forKey: .amenities)
        notes = try container.decode([String].self, forKey: .notes)

        let legacyReviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
        familyReviews = try container.decodeIfPresent([Review].self, forKey: .familyReviews) ?? legacyReviews.filter { $0.isFamilyReview }
        if let explicitCommunityReviews = try container.decodeIfPresent([Review].self, forKey: .communityReviews) {
            communityReviews = explicitCommunityReviews
        } else if familyReviews.isEmpty {
            communityReviews = legacyReviews
        } else {
            communityReviews = legacyReviews.filter { !$0.isFamilyReview }
        }

        userRating = try container.decodeIfPresent(Double.self, forKey: .userRating)
        userReview = try container.decodeIfPresent(Review.self, forKey: .userReview)
    }

    var orderedPhotos: [Photo] { familyPhotos + communityPhotos }
    var orderedReviews: [Review] { familyReviews + communityReviews }
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
