import Foundation
import MapKit

struct TripLocation: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: TripLocation, rhs: TripLocation) -> Bool {
        lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.description == rhs.description &&
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
}

struct TripLeg: Identifiable, Hashable {
    let id = UUID()
    let dayLabel: String
    let dateRangeDescription: String
    let start: TripLocation
    let end: TripLocation
    let distanceInMiles: Int
    let estimatedDriveTime: String
    let highlights: [String]
    let notes: String?
}

extension TripLeg {
    static let sample: [TripLeg] = {
        let newBraunfels = TripLocation(
            name: "New Braunfels, TX",
            description: "Campground Base",
            coordinate: CLLocationCoordinate2D(latitude: 29.7030, longitude: -98.1245)
        )

        let austin = TripLocation(
            name: "Austin, TX",
            description: "Pecan Grove RV Park",
            coordinate: CLLocationCoordinate2D(latitude: 30.2747, longitude: -97.7404)
        )

        let waco = TripLocation(
            name: "Waco, TX",
            description: "Riverview Resort",
            coordinate: CLLocationCoordinate2D(latitude: 31.5493, longitude: -97.1467)
        )

        let dallas = TripLocation(
            name: "Dallas, TX",
            description: "Lake Ray Roberts",
            coordinate: CLLocationCoordinate2D(latitude: 32.7767, longitude: -96.7970)
        )

        let oklahomaCity = TripLocation(
            name: "Oklahoma City, OK",
            description: "State Fair Park",
            coordinate: CLLocationCoordinate2D(latitude: 35.4676, longitude: -97.5164)
        )

        return [
            TripLeg(
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
