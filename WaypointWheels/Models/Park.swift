import SwiftUI

struct Park: Identifiable, Hashable {
    enum Membership: String, CaseIterable, Identifiable {
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
    }

    struct Amenity: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let systemImage: String
    }

    let id = UUID()
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

    static let sampleData: [Park] = [
        Park(
            name: "Riverbend Retreat",
            state: "TX",
            city: "New Braunfels",
            rating: 4.6,
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
            rating: 4.2,
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
            rating: 3.8,
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
            rating: 4.8,
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
