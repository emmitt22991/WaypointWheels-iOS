import Foundation
import MapKit

// MARK: - Current Location Model

/// Represents the user's current location/stay
struct CurrentLocation: Decodable, Equatable {
    let parkId: Int
    let parkUuid: UUID
    let parkName: String
    let description: String
    let arrivalDate: String?
    let departureDate: String?
    let coordinate: CLLocationCoordinate2D
    
    init(parkId: Int,
         parkUuid: UUID,
         parkName: String,
         description: String,
         arrivalDate: String?,
         departureDate: String?,
         coordinate: CLLocationCoordinate2D) {
        self.parkId = parkId
        self.parkUuid = parkUuid
        self.parkName = parkName
        self.description = description
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.coordinate = coordinate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        parkId = try container.decode(Int.self, forKey: .parkId)
        
        // Decode UUID from string
        if let uuidString = try? container.decode(String.self, forKey: .parkUuid),
           let uuid = UUID(uuidString: uuidString) {
            parkUuid = uuid
        } else if let uuid = try? container.decode(UUID.self, forKey: .parkUuid) {
            parkUuid = uuid
        } else {
            // Fallback: generate UUID from park ID (should match backend)
            parkUuid = UUID()
            print("⚠️ Failed to decode park UUID for current location")
        }
        
        parkName = try container.decode(String.self, forKey: .parkName)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
        departureDate = try container.decodeIfPresent(String.self, forKey: .departureDate)
        
        // Decode coordinate
        if let coordinateDTO = try? container.decode(TripLocation.CoordinateDTO.self, forKey: .coordinate) {
            coordinate = CLLocationCoordinate2D(
                latitude: coordinateDTO.latitude,
                longitude: coordinateDTO.longitude
            )
        } else {
            // Fallback if coordinate structure is different
            coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }
    
    /// Format the date range for display
    var dateRangeDisplay: String {
        guard let arrival = arrivalDate else { return "Current location" }
        
        if let departure = departureDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            
            if let arrivalDate = formatter.date(from: arrival),
               let departureDate = formatter.date(from: departure) {
                formatter.dateFormat = "MMM d"
                let arrivalStr = formatter.string(from: arrivalDate)
                let departureStr = formatter.string(from: departureDate)
                
                if arrivalStr == departureStr {
                    return arrivalStr
                }
                return "\(arrivalStr) – \(departureStr)"
            }
        }
        
        // Just show arrival if we have it
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let arrivalDate = formatter.date(from: arrival) {
            formatter.dateFormat = "MMM d"
            return "Since " + formatter.string(from: arrivalDate)
        }
        
        return "Current location"
    }
    
    static func == (lhs: CurrentLocation, rhs: CurrentLocation) -> Bool {
        return lhs.parkId == rhs.parkId &&
               lhs.parkUuid == rhs.parkUuid &&
               lhs.parkName == rhs.parkName &&
               lhs.description == rhs.description &&
               lhs.arrivalDate == rhs.arrivalDate &&
               lhs.departureDate == rhs.departureDate
    }
    
    private enum CodingKeys: String, CodingKey {
        case parkId = "park_id"
        case parkUuid = "park_uuid"
        case parkName = "park_name"
        case description
        case arrivalDate = "arrival_date"
        case departureDate = "departure_date"
        case coordinate
    }
}

// MARK: - Trip Location Model

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

        name = try container.decode(String.self, forKey: .name)

        let providedDescription = TripLocation.trimmedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .description)
        )
        let city = TripLocation.trimmedNonEmpty(try container.decodeIfPresent(String.self, forKey: .city))
        let state = TripLocation.trimmedNonEmpty(try container.decodeIfPresent(String.self, forKey: .state))

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

        let providedID = TripLocation.trimmedNonEmpty(try container.decodeIfPresent(String.self, forKey: .id))

        id = providedID
            ?? TripLocation.makeCoordinateIdentifier(from: coordinate)

        description = providedDescription
            ?? TripLocation.makeDescription(city: city, state: state)
            ?? name
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
        case city
        case state
    }
}

private extension TripLocation {
    static func trimmedNonEmpty(_ string: String?) -> String? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func makeDescription(city: String?, state: String?) -> String? {
        switch (city, state) {
        case let (.some(city), .some(state)):
            return "\(city), \(state)"
        case let (.some(city), nil):
            return city
        case let (nil, .some(state)):
            return state
        default:
            return nil
        }
    }

    static func makeCoordinateIdentifier(from coordinate: CLLocationCoordinate2D) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        let latitude = String(format: "%.6f", locale: locale, coordinate.latitude)
        let longitude = String(format: "%.6f", locale: locale, coordinate.longitude)
        return "coord_lat_\(latitude)_lon_\(longitude)"
    }
}

// MARK: - Trip Leg Model

struct TripLeg: Identifiable, Hashable, Decodable {
    let id: String
    let dayLabel: String
    let dateRangeDescription: String
    let start: TripLocation
    let end: TripLocation
    let distanceInMiles: Double
    let estimatedDriveTime: String
    let highlights: [String]
    let notes: String?
    let isFromCurrentLocation: Bool

    init(id: String,
         dayLabel: String,
         dateRangeDescription: String,
         start: TripLocation,
         end: TripLocation,
         distanceInMiles: Double,
         estimatedDriveTime: String,
         highlights: [String],
         notes: String?,
         isFromCurrentLocation: Bool = false) {
        self.id = id
        self.dayLabel = dayLabel
        self.dateRangeDescription = dateRangeDescription
        self.start = start
        self.end = end
        self.distanceInMiles = distanceInMiles
        self.estimatedDriveTime = estimatedDriveTime
        self.highlights = highlights
        self.notes = notes
        self.isFromCurrentLocation = isFromCurrentLocation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        dayLabel = try container.decode(String.self, forKey: .dayLabel)
        dateRangeDescription = try container.decode(String.self, forKey: .dateRangeDescription)
        start = try container.decode(TripLocation.self, forKey: .start)
        end = try container.decode(TripLocation.self, forKey: .end)
        
        // Handle distance as either Double or String
        if let doubleValue = try? container.decode(Double.self, forKey: .distanceInMiles) {
            distanceInMiles = doubleValue
        } else if let raw = try? container.decode(String.self, forKey: .distanceInMiles),
                  let value = Double(raw) {
            distanceInMiles = value
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .distanceInMiles,
                in: container,
                debugDescription: "Unable to decode distance_in_miles as Double or numeric String"
            )
        }
        
        estimatedDriveTime = try container.decode(String.self, forKey: .estimatedDriveTime)
        
        // Handle highlights as either array or string
        if let highlightArray = try? container.decode([String].self, forKey: .highlights) {
            highlights = highlightArray
        } else {
            let rawHighlights = try container.decode(String.self, forKey: .highlights)
            highlights = TripLeg.normalizeHighlights(from: rawHighlights)
        }
        
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isFromCurrentLocation = try container.decodeIfPresent(Bool.self, forKey: .isFromCurrentLocation) ?? false
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
        case isFromCurrentLocation = "is_from_current_location"
    }
}

private extension TripLeg {
    static func normalizeHighlights(from rawString: String) -> [String] {
        var normalized = rawString.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let bulletTokens = ["•", "*", "- ", "– ", "— "]
        for token in bulletTokens {
            normalized = normalized.replacingOccurrences(of: token, with: "\n")
        }

        let components = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if components.isEmpty, !normalized.isEmpty {
            return [normalized]
        }

        return components.isEmpty ? [] : components
    }
}

// MARK: - Preview Data

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
                dayLabel: "Next Trip",
                dateRangeDescription: "Mon · Apr 14",
                start: newBraunfels,
                end: austin,
                distanceInMiles: 49.0,
                estimatedDriveTime: "1 hr 5 min",
                highlights: [
                    "Depart by 8:00 AM to beat the traffic",
                    "Brunch stop at Magnolia Cafe",
                    "Evening stroll through Zilker Park"
                ],
                notes: "Austin is a quick drive – fuel up the night before.",
                isFromCurrentLocation: true
            ),
            TripLeg(
                id: "leg-2",
                dayLabel: "Travel Day",
                dateRangeDescription: "Wed · Apr 16",
                start: austin,
                end: waco,
                distanceInMiles: 102.0,
                estimatedDriveTime: "1 hr 45 min",
                highlights: [
                    "Arrive by lunch for a riverside picnic",
                    "Tour the Waco Mammoth National Monument",
                    "Book sunset kayaking on the Brazos"
                ],
                notes: "Campground has limited shade – plan for awning setup."
            ),
            TripLeg(
                id: "leg-3",
                dayLabel: "Travel Day",
                dateRangeDescription: "Sat · Apr 19",
                start: waco,
                end: dallas,
                distanceInMiles: 96.0,
                estimatedDriveTime: "1 hr 35 min",
                highlights: [
                    "Grab kolaches at Czech Stop on the way",
                    "Set up bikes for the Katy Trail",
                    "Dinner reservation at Trinity Groves"
                ],
                notes: "Expect more traffic approaching Dallas – plan an early arrival."
            ),
            TripLeg(
                id: "leg-4",
                dayLabel: "Travel Day",
                dateRangeDescription: "Tue · Apr 22",
                start: dallas,
                end: oklahomaCity,
                distanceInMiles: 205.0,
                estimatedDriveTime: "3 hr 15 min",
                highlights: [
                    "Stretch break at Turner Falls Park",
                    "Check in before 4:00 PM for full hookups",
                    "Tickets for the Cowboy Museum night tour"
                ],
                notes: "Longest drive of the route – confirm tire pressure before departure."
            )
        ]
    }()
}

extension CurrentLocation {
    static let previewData = CurrentLocation(
        parkId: 301,
        parkUuid: UUID(uuidString: "0000012d-0000-4000-8000-0000473d8bc0")!, // Generated from parkId 301
        parkName: "New Braunfels, TX",
        description: "Campground Base",
        arrivalDate: "2025-04-10",
        departureDate: "2025-04-14",
        coordinate: CLLocationCoordinate2D(latitude: 29.7030, longitude: -98.1245)
    )
}
#endif
