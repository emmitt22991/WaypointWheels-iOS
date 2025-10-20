import SwiftUI

struct Park: Identifiable, Hashable, Decodable {
    enum Membership: String, CaseIterable, Identifiable, Codable {
        case thousandTrails = "Thousand Trails"
        case koa = "KOA"
        case harvestHosts = "Harvest Hosts"
        case passportAmerica = "Passport America"
        case independent = "Independent"

        var id: String { rawValue }

        var badgeColor: Color {
            switch self {
            case .thousandTrails:
                return Color(red: 0.20, green: 0.52, blue: 0.36)
            case .koa:
                return Color(red: 0.96, green: 0.73, blue: 0.26)
            case .harvestHosts:
                return Color(red: 0.47, green: 0.34, blue: 0.58)
            case .passportAmerica:
                return Color(red: 0.18, green: 0.32, blue: 0.60)
            case .independent:
                return Color(red: 0.36, green: 0.31, blue: 0.55)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = Membership(rawValue: rawValue) ?? .independent
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
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
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        state = try container.decode(String.self, forKey: .state)
        city = try container.decode(String.self, forKey: .city)

        let legacyRating = try container.decodeIfPresent(Double.self, forKey: .rating)
        familyRating = try container.decodeIfPresent(Double.self, forKey: .familyRating) ?? legacyRating ?? 0
        communityRating = try container.decodeIfPresent(Double.self, forKey: .communityRating)
        familyReviewCount = try container.decodeIfPresent(Int.self, forKey: .familyReviewCount) ?? 0
        communityReviewCount = try container.decodeIfPresent(Int.self, forKey: .communityReviewCount) ?? 0

        description = try container.decode(String.self, forKey: .description)
        memberships = try container.decode([Membership].self, forKey: .memberships)
        amenities = try container.decode([Amenity].self, forKey: .amenities)
        featuredNotes = try container.decode([String].self, forKey: .featuredNotes)
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
            memberships: [.thousandTrails, .harvestHosts],
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
            memberships: [.koa, .passportAmerica],
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
            memberships: [.thousandTrails, .independent],
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
            memberships: [.harvestHosts, .independent],
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
