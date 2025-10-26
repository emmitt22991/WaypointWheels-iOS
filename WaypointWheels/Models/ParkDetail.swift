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
            
            // Handle UUID as string
            if let idString = try? container.decode(String.self, forKey: .id),
               let uuid = UUID(uuidString: idString) {
                id = uuid
            } else {
                id = try container.decode(UUID.self, forKey: .id)
            }
            
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
            
            // CRITICAL FIX: Handle UUID as string (from JSON) or native UUID
            if let idString = try? container.decode(String.self, forKey: .id),
               let uuid = UUID(uuidString: idString) {
                id = uuid
                print("✅ Successfully decoded review UUID from string: \(idString)")
            } else if let uuid = try? container.decode(UUID.self, forKey: .id) {
                id = uuid
                print("✅ Successfully decoded review UUID directly")
            } else {
                print("❌ Failed to decode review ID, generating new UUID")
                id = UUID()
            }
            
            authorName = try container.decode(String.self, forKey: .authorName)
            
            // Handle rating as either Int or Double
            rating = container.decodeFlexibleDouble(forKey: .rating) ?? 0
            
            comment = try container.decode(String.self, forKey: .comment)
            
            // Parse date string with ISO8601 formatter
            let dateString = try container.decode(String.self, forKey: .createdAt)
            if let date = ISO8601DateFormatter.cachedFormatter.date(from: dateString) {
                createdAt = date
                print("✅ Successfully parsed date: \(dateString)")
            } else {
                print("⚠️ Failed to parse date: \(dateString), using current date")
                createdAt = Date()
            }
            
            isFamilyReview = try container.decodeIfPresent(Bool.self, forKey: .isFamilyReview) ?? false
            
            print("✅ Successfully decoded review: ID=\(id), author=\(authorName), rating=\(rating)")
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
        
        print("🔍 Decoding ParkDetail...")
        
        summary = try container.decode(Park.self, forKey: .summary)
        print("✅ Decoded park summary: \(summary.name)")

        let legacyPhotos = try container.decodeIfPresent([Photo].self, forKey: .photos) ?? []
        familyPhotos = try container.decodeIfPresent([Photo].self, forKey: .familyPhotos) ?? legacyPhotos.filter { $0.isFamilyPhoto }
        if let explicitCommunityPhotos = try container.decodeIfPresent([Photo].self, forKey: .communityPhotos) {
            communityPhotos = explicitCommunityPhotos
        } else if familyPhotos.isEmpty {
            communityPhotos = legacyPhotos
        } else {
            communityPhotos = legacyPhotos.filter { !$0.isFamilyPhoto }
        }
        print("✅ Decoded photos: \(familyPhotos.count) family, \(communityPhotos.count) community")

        amenities = try container.decode([Park.Amenity].self, forKey: .amenities)
        notes = try container.decode([String].self, forKey: .notes)
        print("✅ Decoded amenities: \(amenities.count), notes: \(notes.count)")

        // CRITICAL FIX: Add detailed logging for review decoding
        print("🔍 Attempting to decode reviews...")
        
        let legacyReviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
        print("   - Legacy reviews: \(legacyReviews.count)")
        
        // Try to decode family_reviews with error handling
        if let familyReviewsArray = try? container.decode([Review].self, forKey: .familyReviews) {
            familyReviews = familyReviewsArray
            print("✅ Successfully decoded \(familyReviews.count) family reviews")
        } else {
            print("⚠️ Failed to decode family_reviews, using legacy filter")
            familyReviews = legacyReviews.filter { $0.isFamilyReview }
        }
        
        // Try to decode community_reviews with error handling
        if let explicitCommunityReviews = try? container.decode([Review].self, forKey: .communityReviews) {
            communityReviews = explicitCommunityReviews
            print("✅ Successfully decoded \(communityReviews.count) community reviews")
        } else if familyReviews.isEmpty {
            communityReviews = legacyReviews
            print("   - Using legacy reviews as community reviews")
        } else {
            communityReviews = legacyReviews.filter { !$0.isFamilyReview }
            print("   - Using filtered legacy reviews as community reviews")
        }
        
        print("✅ Final review counts: family=\(familyReviews.count), community=\(communityReviews.count)")

        userRating = container.decodeFlexibleDouble(forKey: .userRating)
        userReview = try container.decodeIfPresent(Review.self, forKey: .userReview)
        
        if let userRating = userRating {
            print("✅ User rating: \(userRating)")
        }
        if userReview != nil {
            print("✅ User has submitted a review")
        }
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
