import Foundation
import MapKit

struct TripLocation: Identifiable, Hashable, Decodable {
    struct CoordinateDTO: Decodable {
        let latitude: Double
        let longitude: Double
    }

    let id: String
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D

    init(id: String, name: String, description: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.description = description
        self.coordinate = coordinate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)

        if let coordinateDTO = try? container.decode(CoordinateDTO.self, forKey: .coordinate) {
            coordinate = CLLocationCoordinate2D(
                latitude: coordinateDTO.latitude,
                longitude: coordinateDTO.longitude
            )
        } else {
            let latitude = try container.decode(Double.self, forKey: .latitude)
            let longitude = try container.decode(Double.self, forKey: .longitude)
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    static func == (lhs: TripLocation, rhs: TripLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case coordinate
        case latitude
        case longitude
    }
}

struct TripLeg: Identifiable, Hashable, Decodable {
    let id: String
    let dayLabel: String
    let dateRangeDescription: String
    let start: TripLocation
    let end: TripLocation
    let distanceInMiles: Int
    let estimatedDriveTime: String
    let highlights: [String]
    let notes: String?

    init(id: String,
         dayLabel: String,
         dateRangeDescription: String,
         start: TripLocation,
         end: TripLocation,
         distanceInMiles: Int,
         estimatedDriveTime: String,
         highlights: [String],
         notes: String?) {
        self.id = id
        self.dayLabel = dayLabel
        self.dateRangeDescription = dateRangeDescription
        self.start = start
        self.end = end
        self.distanceInMiles = distanceInMiles
        self.estimatedDriveTime = estimatedDriveTime
        self.highlights = highlights
        self.notes = notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        dayLabel = try container.decode(String.self, forKey: .dayLabel)
        dateRangeDescription = try container.decode(String.self, forKey: .dateRangeDescription)
        start = try container.decode(TripLocation.self, forKey: .start)
        end = try container.decode(TripLocation.self, forKey: .end)
        distanceInMiles = try container.decode(Int.self, forKey: .distanceInMiles)
        estimatedDriveTime = try container.decode(String.self, forKey: .estimatedDriveTime)
        highlights = try container.decode([String].self, forKey: .highlights)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case dayLabel = "day_label"
        case dateRangeDescription = "date_range_description"
        case start
        case end
        case distanceInMiles = "distance_in_miles"
        case estimatedDriveTime = "estimated_drive_time"
        case highlights
        case notes
    }
}

#if DEBUG
extension TripLeg {
    static let previewData: [TripLeg] = {
        let newBraunfels = TripLocation(
            id: "loc-new-braunfels",
            name: "New Braunfels, TX",
            description: "Campground Base",
            coordinate: CLLocationCoordinate2D(latitude: 29.7030, longitude: -98.1245)
        )

        let austin = TripLocation(
            id: "loc-austin",
            name: "Austin, TX",
            description: "Pecan Grove RV Park",
            coordinate: CLLocationCoordinate2D(latitude: 30.2747, longitude: -97.7404)
        )

        let waco = TripLocation(
            id: "loc-waco",
            name: "Waco, TX",
            description: "Riverview Resort",
            coordinate: CLLocationCoordinate2D(latitude: 31.5493, longitude: -97.1467)
        )

        let dallas = TripLocation(
            id: "loc-dallas",
            name: "Dallas, TX",
            description: "Lake Ray Roberts",
            coordinate: CLLocationCoordinate2D(latitude: 32.7767, longitude: -96.7970)
        )

        let oklahomaCity = TripLocation(
            id: "loc-okc",
            name: "Oklahoma City, OK",
            description: "State Fair Park",
            coordinate: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164)
        )

        return [
            TripLeg(
                id: "leg-1",
                dayLabel: "Leg 1",
                dateRangeDescription: "Mon · Apr 14",
                start: newBraunfels,
                end: austin,
                distanceInMiles: 49,
                estimatedDriveTime: "1 hr 5 min",
                highlights: [
                    "Depart by 8:00 AM to beat the traffic",
                    "Brunch stop at Magnolia Cafe",
                    "Evening stroll through Zilker Park"
                ],
                notes: "Austin is a quick drive — fuel up the night before."
            ),
            TripLeg(
                id: "leg-2",
                dayLabel: "Leg 2",
                dateRangeDescription: "Wed · Apr 16",
                start: austin,
                end: waco,
                distanceInMiles: 102,
                estimatedDriveTime: "1 hr 45 min",
                highlights: [
                    "Arrive by lunch for a riverside picnic",
                    "Tour the Waco Mammoth National Monument",
                    "Book sunset kayaking on the Brazos"
                ],
                notes: "Campground has limited shade — plan for awning setup."
            ),
            TripLeg(
                id: "leg-3",
                dayLabel: "Leg 3",
                dateRangeDescription: "Sat · Apr 19",
                start: waco,
                end: dallas,
                distanceInMiles: 96,
                estimatedDriveTime: "1 hr 35 min",
                highlights: [
                    "Grab kolaches at Czech Stop on the way",
                    "Set up bikes for the Katy Trail",
                    "Dinner reservation at Trinity Groves"
                ],
                notes: "Expect more traffic approaching Dallas — plan an early arrival."
            ),
            TripLeg(
                id: "leg-4",
                dayLabel: "Leg 4",
                dateRangeDescription: "Tue · Apr 22",
                start: dallas,
                end: oklahomaCity,
                distanceInMiles: 205,
                estimatedDriveTime: "3 hr 15 min",
                highlights: [
                    "Stretch break at Turner Falls Park",
                    "Check in before 4:00 PM for full hookups",
                    "Tickets for the Cowboy Museum night tour"
                ],
                notes: "Longest drive of the route — confirm tire pressure before departure."
            )
        ]
    }()
}
#endif
