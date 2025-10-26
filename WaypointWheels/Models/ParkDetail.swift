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
            
            // CRITICAL FIX: Decode UUID from string, just like Park does
            // The JSON has id as a string, not a native UUID type
            if let idString = try? container.decode(String.self, forKey: .id),
               let uuid = UUID(uuidString: idString) {
                id = uuid
                print("✅ Decoded photo ID from string: \(idString)")
            } else if let uuid = try? container.decode(UUID.self, forKey: .id) {
                id = uuid
                print("✅ Decoded photo ID as UUID directly")
            } else {
                print("⚠️ Failed to decode photo ID, generating new UUID")
                id = UUID()
            }
            
            imageURL = try container.decode(URL.self, forKey: .imageURL)
            caption = try container.decodeIfPresent(String.self, forKey: .caption)
            uploadedBy = try container.decodeIfPresent(String.self, forKey: .uploadedBy)
            isFamilyPhoto = try container.decodeIfPresent(Bool.self, forKey: .isFamilyPhoto) ?? false
            
            print("✅ Successfully decoded photo: \(imageURL)")
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
            
            // CRITICAL FIX: Decode UUID from string, just like Park does
            // The JSON has id as a string, not a native UUID type
            if let idString = try? container.decode(String.self, forKey: .id),
               let uuid = UUID(uuidString: idString) {
                id = uuid
                print("✅ Decoded review ID from string: \(idString)")
            } else if let uuid = try? container.decode(UUID.self, forKey: .id) {
                id = uuid
                print("✅ Decoded review ID as UUID directly")
            } else {
                print("⚠️ Failed to decode review ID, generating new UUID")
                id = UUID()
            }
            
            authorName = try container.decode(String.self, forKey: .authorName)
            print("✅ Decoded review author: \(authorName)")
            
            rating = container.decodeFlexibleDouble(forKey: .rating) ?? 0
            print("✅ Decoded review rating: \(rating)")
            
            comment = try container.decode(String.self, forKey: .comment)
            print("✅ Decoded review comment (length: \(comment.count))")
            
            let dateString = try container.decode(String.self, forKey: .createdAt)
            print("✅ Decoded date string: \(dateString)")
            
            if let parsedDate = ISO8601DateFormatter.cachedFormatter.date(from: dateString) {
                createdAt = parsedDate
                print("✅ Successfully parsed date: \(parsedDate)")
            } else {
                createdAt = Date()
                print("⚠️ Failed to parse date '\(dateString)', using current date")
            }
            
            isFamilyReview = try container.decodeIfPresent(Bool.self, forKey: .isFamilyReview) ?? false
            print("✅ Decoded is_family_review: \(isFamilyReview)")
            print("✅ Successfully decoded complete review for: \(authorName)")
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
        
        print("🔍 Starting ParkDetail decoding...")
        
        summary = try container.decode(Park.self, forKey: .summary)
        print("✅ Decoded park summary: \(summary.name)")

        let legacyPhotos = try container.decodeIfPresent([Photo].self, forKey: .photos) ?? []
        print("📸 Legacy photos: \(legacyPhotos.count)")
        
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

        print("🔍 Attempting to decode reviews...")
        
        let legacyReviews = try container.decodeIfPresent([Review].self, forKey: .reviews) ?? []
        print("  - Legacy reviews: \(legacyReviews.count)")
        
        // CRITICAL: Use try instead of decodeIfPresent to get the actual error
        // decodeIfPresent silently returns nil when array decode fails
        do {
            // First check if the key exists
            if container.contains(.familyReviews) {
                print("  - family_reviews key EXISTS in JSON")
                // Now try to decode it and catch the actual error
                let decodedFamilyReviews = try container.decode([Review].self, forKey: .familyReviews)
                familyReviews = decodedFamilyReviews
                print("✅ Successfully decoded family_reviews: \(familyReviews.count) reviews")
            } else {
                print("  - family_reviews key MISSING from JSON")
                familyReviews = legacyReviews.filter { $0.isFamilyReview }
                print("  - Using legacy filter: \(familyReviews.count) reviews")
            }
        } catch let decodingError as DecodingError {
            print("❌ DECODE ERROR for family_reviews:")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("  - Key not found: \(key)")
                print("  - Context: \(context.debugDescription)")
                print("  - Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .typeMismatch(let type, let context):
                print("  - Type mismatch: expected \(type)")
                print("  - Context: \(context.debugDescription)")
                print("  - Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("  - Underlying error: \(String(describing: context.underlyingError))")
            case .valueNotFound(let type, let context):
                print("  - Value not found: \(type)")
                print("  - Context: \(context.debugDescription)")
                print("  - Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
            case .dataCorrupted(let context):
                print("  - Data corrupted")
                print("  - Context: \(context.debugDescription)")
                print("  - Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                print("  - Underlying error: \(String(describing: context.underlyingError))")
            @unknown default:
                print("  - Unknown decoding error: \(decodingError)")
            }
            // Fall back to legacy filter
            familyReviews = legacyReviews.filter { $0.isFamilyReview }
            print("  - Falling back to legacy filter: \(familyReviews.count) reviews")
        } catch {
            print("❌ NON-DECODING ERROR for family_reviews: \(error)")
            print("  - Error type: \(type(of: error))")
            print("  - Error description: \(error.localizedDescription)")
            familyReviews = legacyReviews.filter { $0.isFamilyReview }
            print("  - Falling back to legacy filter: \(familyReviews.count) reviews")
        }
        
        // Try to decode community_reviews
        if let explicitCommunityReviews = try container.decodeIfPresent([Review].self, forKey: .communityReviews) {
            communityReviews = explicitCommunityReviews
            print("✅ Successfully decoded community_reviews: \(communityReviews.count) reviews")
        } else if familyReviews.isEmpty {
            communityReviews = legacyReviews
            print("  - Using legacy reviews as community reviews: \(communityReviews.count)")
        } else {
            communityReviews = legacyReviews.filter { !$0.isFamilyReview }
            print("  - Filtered legacy for community reviews: \(communityReviews.count)")
        }
        
        print("✅ Final review counts: family=\(familyReviews.count), community=\(communityReviews.count)")

        userRating = container.decodeFlexibleDouble(forKey: .userRating)
        userReview = try container.decodeIfPresent(Review.self, forKey: .userReview)
        
        if let userRating = userRating {
            print("✅ User has rating: \(userRating)")
        }
        if userReview != nil {
            print("✅ User has review")
        }
        
        print("✅ ParkDetail decoding complete!")
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
