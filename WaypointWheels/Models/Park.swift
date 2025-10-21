import SwiftUI

struct Park: Identifiable, Hashable, Decodable {
    struct Membership: Identifiable, Hashable, Codable {
        let name: String
        
        var id: String { name }
        
        var badgeColor: Color {
            // Generate a consistent color based on the membership name
            let hash = name.utf8.reduce(0) { ($0 &+ UInt64($1)) }
            
            // Use golden ratio for better color distribution
            let hue = Double((hash % 360)) / 360.0
            
            // Keep saturation and brightness in pleasant ranges
            let saturation = 0.6 + (Double((hash >> 8) % 20) / 100.0) // 0.6-0.8
            let brightness = 0.7 + (Double((hash >> 16) % 20) / 100.0) // 0.7-0.9
            
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }
        
        init(name: String) {
            self.name = name
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            self.name = try container.decode(String.self)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        }
    }

    struct Amenity: Identifiable, Hashable, Codable {
        let id: UUID
        let name: String
        let systemImage: String

        init(id: UUID = UUID(), name: String, systemImage: String) {
            self.id = id
            self.name = name
            self.systemImage = systemImage
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case systemImage = "system_image"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let idString = try? container.decode(String.self, forKey: .id),
               let uuid = UUID(uuidString: idString) {
                id = uuid
            } else if let uuid = try? container.decode(UUID.self, forKey: .id) {
                id = uuid
            } else {
                id = UUID()
            }
            
            name = try container.decode(String.self, forKey: .name)
            systemImage = try container.decode(String.self, forKey: .systemImage)
        }
    }

    let id: UUID
    let name: String
    let state: String
    let city: String
    let familyRating: Double
    let communityRating: Double?
    let familyReviewCount: Int
    let communityReviewCount: Int
    let description: String
    let memberships: [Membership]
    let amenities: [Amenity]
    let featuredNotes: [String]

    init(id: UUID = UUID(),
         name: String,
         state: String,
         city: String,
         familyRating: Double,
         communityRating: Double? = nil,
         familyReviewCount: Int = 0,
         communityReviewCount: Int = 0,
         description: String,
         memberships: [Membership],
         amenities: [Amenity],
         featuredNotes: [String]) {
        self.id = id
        self.name = name
        self.state = state
        self.city = city
        self.familyRating = familyRating
        self.communityRating = communityRating
        self.familyReviewCount = familyReviewCount
        self.communityReviewCount = communityReviewCount
        self.description = description
        self.memberships = memberships
        self.amenities = amenities
        self.featuredNotes = featuredNotes
    }

    var formattedLocation: String {
        "\(city), \(state)"
    }

    var rating: Double { familyRating }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case state
        case city
        case rating
        case familyRating = "family_rating"
        case communityRating = "community_rating"
        case familyReviewCount = "family_review_count"
        case communityReviewCount = "community_review_count"
        case description
        case memberships
        case amenities
        case featuredNotes = "featured_notes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let idString = try? container.decode(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            id = uuid
        } else if let uuid = try? container.decode(UUID.self, forKey: .id) {
            id = uuid
        } else {
            print("⚠️ Failed to decode park ID, generating new UUID")
            id = UUID()
        }
        
        name = try container.decode(String.self, forKey: .name)
        state = try container.decode(String.self, forKey: .state)
        city = try container.decode(String.self, forKey: .city)

        let legacyRating = try container.decodeIfPresent(Double.self, forKey: .rating)
        familyRating = try container.decodeIfPresent(Double.self, forKey: .familyRating) ?? legacyRating ?? 0
        
        communityRating = try container.decodeIfPresent(Double.self, forKey: .communityRating)
        
        familyReviewCount = try container.decodeIfPresent(Int.self, forKey: .familyReviewCount) ?? 0
        communityReviewCount = try container.decodeIfPresent(Int.self, forKey: .communityReviewCount) ?? 0

        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        
        let membershipStrings = (try? container.decode([String].self, forKey: .memberships)) ?? []
        memberships = membershipStrings.map { Membership(name: $0) }
        
        amenities = (try? container.decode([Amenity].self, forKey: .amenities)) ?? []
        
        featuredNotes = (try? container.decode([String].self, forKey: .featuredNotes)) ?? []
        
        print("✅ Successfully decoded park: \(name) in \(city), \(state)")
    }

    static let sampleData: [Park] = [
        Park(
            name: "Riverbend Retreat",
            state: "TX",
            city: "New Braunfels",
            familyRating: 4.6,
            communityRating: 4.4,
            familyReviewCount: 12,
            communityReviewCount: 64,
            description: "Nestled right along the Guadalupe River, Riverbend Retreat offers oversized pull-through sites, shade from towering pecan trees, and quick access to tubing outfitters.",
            memberships: [Membership(name: "Thousand Trails"), Membership(name: "Harvest Hosts")],
            amenities: [
                Amenity(name: "50 AMP Full Hookups", systemImage: "bolt.fill"),
                Amenity(name: "River Access", systemImage: "drop.fill"),
                Amenity(name: "Pool & Hot Tub", systemImage: "figure.pool.swim")
            ],
            featuredNotes: [
                "Family favorite for summer floating trips",
                "Friendly hosts who remember returning members",
                "Reserve the riverfront premium sites early"
            ]
        ),
        Park(
            name: "Juniper Ridge Camp",
            state: "UT",
            city: "Moab",
            familyRating: 4.2,
            communityRating: 4.0,
            familyReviewCount: 9,
            communityReviewCount: 38,
            description: "Wake up to red rock views and be minutes away from both Arches and Canyonlands National Parks. Juniper Ridge balances rustic desert vibes with modern amenities.",
            memberships: [Membership(name: "KOA"), Membership(name: "Passport America")],
            amenities: [
                Amenity(name: "Adventure Concierge", systemImage: "figure.hiking"),
                Amenity(name: "Camp Store", systemImage: "bag.fill"),
                Amenity(name: "Desert Wi-Fi Lounge", systemImage: "wifi")
            ],
            featuredNotes: [
                "Ask for the rim-view sites when booking",
                "Pool is clutch after a day on the trails"
            ]
        ),
        Park(
            name: "Evergreen Lakeside",
            state: "WA",
            city: "Leavenworth",
            familyRating: 3.8,
            communityRating: 3.9,
            familyReviewCount: 7,
            communityReviewCount: 22,
            description: "A pine-canopied hideaway with waterfront sites on Icicle Creek. This stop is perfect for quiet mornings, paddle boarding, and quick trips into Bavarian downtown.",
            memberships: [Membership(name: "Thousand Trails"), Membership(name: "Independent")],
            amenities: [
                Amenity(name: "Creekside Kayak Launch", systemImage: "sailboat.fill"),
                Amenity(name: "Laundry Cottage", systemImage: "washer"),
                Amenity(name: "Seasonal Events Pavilion", systemImage: "tent.2.fill")
            ],
            featuredNotes: [
                "Shaded sites stay cooler mid-summer",
                "Limited cell service—download maps ahead"
            ]
        ),
        Park(
            name: "Sunset Mesa RV Resort",
            state: "AZ",
            city: "Sedona",
            familyRating: 4.8,
            communityRating: 4.6,
            familyReviewCount: 16,
            communityReviewCount: 71,
            description: "Perched above the red rocks, Sunset Mesa delivers panoramic sunsets, curated wellness programming, and easy day trips into uptown Sedona.",
            memberships: [Membership(name: "Harvest Hosts"), Membership(name: "Independent")],
            amenities: [
                Amenity(name: "On-Site Trailheads", systemImage: "leaf.fill"),
                Amenity(name: "Wellness Yurts", systemImage: "figure.mind.and.body"),
                Amenity(name: "Outdoor Kitchen", systemImage: "flame")
            ],
            featuredNotes: [
                "Our go-to for anniversary trips",
                "Book a sunset yoga session at the ridge"
            ]
        )
    ]
}

extension Park {
    func updating(familyRating: Double? = nil,
                  communityRating: Double?? = nil,
                  familyReviewCount: Int? = nil,
                  communityReviewCount: Int? = nil) -> Park {
        Park(
            id: id,
            name: name,
            state: state,
            city: city,
            familyRating: familyRating ?? self.familyRating,
            communityRating: communityRating ?? self.communityRating,
            familyReviewCount: familyReviewCount ?? self.familyReviewCount,
            communityReviewCount: communityReviewCount ?? self.communityReviewCount,
            description: description,
            memberships: memberships,
            amenities: amenities,
            featuredNotes: featuredNotes
        )
    }
}
