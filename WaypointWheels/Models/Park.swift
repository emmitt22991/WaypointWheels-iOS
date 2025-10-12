import SwiftUI

struct Park: Identifiable, Hashable, Decodable {
    enum Membership: String, Identifiable, CaseIterable, Codable {
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

    struct Amenity: Identifiable, Hashable, Decodable {
        let name: String
        let systemImage: String

        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name
            case systemImage = "system_image"
        }
    }

    let id: String
    let name: String
    let state: String
    let city: String
    let rating: Double
    let description: String
    let memberships: [Membership]
    let amenities: [Amenity]
    let featuredNotes: [String]

    var formattedLocation: String {
        "\(city), \(state)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case state
        case city
        case rating
        case description
        case memberships
        case amenities
        case featuredNotes = "featured_notes"
    }

    init(id: String,
         name: String,
         state: String,
         city: String,
         rating: Double,
         description: String,
         memberships: [Membership],
         amenities: [Amenity],
         featuredNotes: [String]) {
        self.id = id
        self.name = name
        self.state = state
        self.city = city
        self.rating = rating
        self.description = description
        self.memberships = memberships
        self.amenities = amenities
        self.featuredNotes = featuredNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        state = try container.decode(String.self, forKey: .state)
        city = try container.decode(String.self, forKey: .city)
        rating = try container.decode(Double.self, forKey: .rating)
        description = try container.decode(String.self, forKey: .description)

        let rawMemberships = try container.decodeIfPresent([String].self, forKey: .memberships) ?? []
        memberships = rawMemberships.compactMap { Membership(rawValue: $0) }

        amenities = try container.decodeIfPresent([Amenity].self, forKey: .amenities) ?? []
        featuredNotes = try container.decodeIfPresent([String].self, forKey: .featuredNotes) ?? []
    }
}
