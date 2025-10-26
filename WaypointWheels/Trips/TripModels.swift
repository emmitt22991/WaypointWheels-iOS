import Foundation
import MapKit

// MARK: - Current Location Model

/// Represents the user's current location/stay during an active trip
/// This shows where the user currently is (their "You are here" location)
struct CurrentLocation: Decodable, Equatable {
    let parkId: Int
    let parkUuid: UUID
    let parkName: String
    let description: String
    let arrivalDate: String?
    let departureDate: String?
    let coordinate: CLLocationCoordinate2D
    
    // MARK: - Initializers
    
    /// Full initializer for creating CurrentLocation instances
    /// - Parameters:
    ///   - parkId: Database ID of the park
    ///   - parkUuid: UUID of the park for API calls
    ///   - parkName: Display name of the park
    ///   - description: Location description (e.g., "Nashville, TN")
    ///   - arrivalDate: ISO date string of arrival (YYYY-MM-DD)
    ///   - departureDate: ISO date string of departure (YYYY-MM-DD)
    ///   - coordinate: Geographic coordinates of the park
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
    
    /// Decode from JSON response
    /// Handles UUID decoding from string format (backend sends UUIDs as strings)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode park ID
        parkId = try container.decode(Int.self, forKey: .parkId)
        print("✅ CurrentLocation: Decoded parkId: \(parkId)")
        
        // Decode UUID from string (backend returns UUID as string, not native UUID)
        if let uuidString = try? container.decode(String.self, forKey: .parkUuid),
           let uuid = UUID(uuidString: uuidString) {
            parkUuid = uuid
            print("✅ CurrentLocation: Decoded parkUuid from string: \(uuidString)")
        } else if let uuid = try? container.decode(UUID.self, forKey: .parkUuid) {
            parkUuid = uuid
            print("✅ CurrentLocation: Decoded parkUuid as native UUID")
        } else {
            // Fallback: generate UUID (shouldn't happen in production)
            parkUuid = UUID()
            print("⚠️ CurrentLocation: Failed to decode park UUID, generated fallback UUID")
        }
        
        // Decode basic fields
        parkName = try container.decode(String.self, forKey: .parkName)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
        departureDate = try container.decodeIfPresent(String.self, forKey: .departureDate)
        
        print("✅ CurrentLocation: Decoded location: \(parkName)")
        if let arrival = arrivalDate {
            print("   - Arrival: \(arrival)")
        }
        if let departure = departureDate {
            print("   - Departure: \(departure)")
        }
        
        // Decode coordinate (backend sends as nested object with lat/long)
        if let coordinateDTO = try? container.decode(TripLocation.CoordinateDTO.self, forKey: .coordinate) {
            coordinate = CLLocationCoordinate2D(
                latitude: coordinateDTO.latitude,
                longitude: coordinateDTO.longitude
            )
            print("✅ CurrentLocation: Decoded coordinate: (\(coordinateDTO.latitude), \(coordinateDTO.longitude))")
        } else {
            // Fallback if coordinate structure is different or missing
            coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            print("⚠️ CurrentLocation: Failed to decode coordinate, using default (0, 0)")
        }
    }
    
    // MARK: - Display Helpers
    
    /// Format the date range for display in the UI
    /// Examples:
    /// - "Apr 10 – Apr 14" (if both dates present)
    /// - "Since Apr 10" (if only arrival date)
    /// - "Current location" (if no dates)
    var dateRangeDisplay: String {
        guard let arrival = arrivalDate else { return "Current location" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // If we have both arrival and departure dates
        if let departure = departureDate,
           let arrivalDate = formatter.date(from: arrival),
           let departureDate = formatter.date(from: departure) {
            formatter.dateFormat = "MMM d"
            let arrivalStr = formatter.string(from: arrivalDate)
            let departureStr = formatter.string(from: departureDate)
            
            // Same date? Just show once
            if arrivalStr == departureStr {
                return arrivalStr
            }
            return "\(arrivalStr) – \(departureStr)"
        }
        
        // Just show arrival if we only have that
        if let arrivalDate = formatter.date(from: arrival) {
            formatter.dateFormat = "MMM d"
            return "Since " + formatter.string(from: arrivalDate)
        }
        
        return "Current location"
    }
    
    // MARK: - Equatable
    
    /// Compare two CurrentLocation instances
    /// Coordinates are intentionally excluded from equality check since they may have floating point precision differences
    static func == (lhs: CurrentLocation, rhs: CurrentLocation) -> Bool {
        return lhs.parkId == rhs.parkId &&
               lhs.parkUuid == rhs.parkUuid &&
               lhs.parkName == rhs.parkName &&
               lhs.description == rhs.description &&
               lhs.arrivalDate == rhs.arrivalDate &&
               lhs.departureDate == rhs.departureDate
    }
    
    // MARK: - Coding Keys
    
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

/// Represents a specific location in a trip (start or end point of a leg)
/// Each location has a name, description, and geographic coordinates
struct TripLocation: Identifiable, Hashable, Decodable {
    
    /// Helper struct for decoding coordinates from backend
    /// Backend sends coordinates as object with separate latitude/longitude fields
    struct CoordinateDTO: Decodable {
        let latitude: Double
        let longitude: Double
    }

    // MARK: - Properties
    
    let id: String
    let name: String
    let description: String
    let coordinate: CLLocationCoordinate2D

    // MARK: - Initializers
    
    /// Create a TripLocation with all fields
    /// - Parameters:
    ///   - id: Unique identifier for this location
    ///   - name: Display name (e.g., "Austin, TX")
    ///   - description: Additional context (e.g., "Pecan Grove RV Park")
    ///   - coordinate: Geographic coordinates
    init(id: String, name: String, description: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.description = description
        self.coordinate = coordinate
    }

    /// Decode from JSON with flexible handling of various formats
    /// The backend may send coordinates in different structures, so we try multiple approaches
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode name
        name = try container.decode(String.self, forKey: .name)

        // Build description from available fields
        // Priority: explicit description > "city, state" > name
        let providedDescription = TripLocation.trimmedNonEmpty(
            try container.decodeIfPresent(String.self, forKey: .description)
        )
        let city = TripLocation.trimmedNonEmpty(try container.decodeIfPresent(String.self, forKey: .city))
        let state = TripLocation.trimmedNonEmpty(try container.decodeIfPresent(String.self, forKey: .state))

        // Try to decode coordinate from nested object, fall back to separate fields
        if let coordinateDTO = try? container.decode(CoordinateDTO.self, forKey: .coordinate) {
            coordinate = CLLocationCoordinate2D(
                latitude: coordinateDTO.latitude,
                longitude: coordinateDTO.longitude
            )
        } else {
            // Fallback: decode from separate latitude/longitude fields
            let latitude = try container.decode(Double.self, forKey: .latitude)
            let longitude = try container.decode(Double.self, forKey: .longitude)
            coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        // Get or generate ID
        let providedID = TripLocation.trimmedNonEmpty(try container.decodeIfPresent(String.self, forKey: .id))

        id = providedID
            ?? TripLocation.makeCoordinateIdentifier(from: coordinate)

        description = providedDescription
            ?? TripLocation.makeDescription(city: city, state: state)
            ?? name
    }

    // MARK: - Equatable & Hashable
    
    /// Two locations are equal if they have the same ID
    static func == (lhs: TripLocation, rhs: TripLocation) -> Bool {
        lhs.id == rhs.id
    }

    /// Hash based on ID only
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Coding Keys
    
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

// MARK: - TripLocation Helpers

private extension TripLocation {
    /// Helper to clean up optional strings
    /// Returns nil if string is nil or contains only whitespace
    static func trimmedNonEmpty(_ string: String?) -> String? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Build a description from city and state components
    /// Returns "City, State", "City", "State", or nil
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

    /// Generate a unique ID from coordinates when no ID is provided
    /// Format: "coord_lat_XX.XXXXXX_lon_YY.YYYYYY"
    static func makeCoordinateIdentifier(from coordinate: CLLocationCoordinate2D) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        let latitude = String(format: "%.6f", locale: locale, coordinate.latitude)
        let longitude = String(format: "%.6f", locale: locale, coordinate.longitude)
        return "coord_lat_\(latitude)_lon_\(longitude)"
    }
}

// MARK: - Trip Leg Model

/// Represents a single leg of a trip (travel from one location to another)
/// Contains departure/arrival info, distance, highlights, and notes
struct TripLeg: Identifiable, Hashable, Decodable {
    
    // MARK: - Properties
    
    let id: String
    let dayLabel: String              // e.g., "Next Trip", "Travel Day"
    let dateRangeDescription: String  // e.g., "Mon · Apr 14"
    let start: TripLocation
    let end: TripLocation
    let distanceInMiles: Double
    let estimatedDriveTime: String    // e.g., "1 hr 5 min"
    let highlights: [String]          // List of notable things to do/see
    let notes: String?                // Optional additional notes
    let isFromCurrentLocation: Bool   // True if this leg starts from where the user currently is

    // MARK: - Initializers
    
    /// Create a complete TripLeg
    /// - Parameters:
    ///   - id: Unique identifier for this leg
    ///   - dayLabel: Display label for the day (e.g., "Next Trip")
    ///   - dateRangeDescription: Formatted date string (e.g., "Mon · Apr 14")
    ///   - start: Starting location
    ///   - end: Ending location
    ///   - distanceInMiles: Distance to travel in miles
    ///   - estimatedDriveTime: Human-readable drive time (e.g., "2 hr 30 min")
    ///   - highlights: List of notable stops/activities along the way
    ///   - notes: Optional additional information
    ///   - isFromCurrentLocation: Whether this is the next leg from current location
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

    /// Decode from JSON with flexible handling
    /// Backend may send distance as string or number, highlights as array or string
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode basic fields
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
        
        // Handle highlights as either array or string with bullet points
        if let highlightArray = try? container.decode([String].self, forKey: .highlights) {
            highlights = highlightArray
        } else {
            let rawHighlights = try container.decode(String.self, forKey: .highlights)
            highlights = TripLeg.normalizeHighlights(from: rawHighlights)
        }
        
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isFromCurrentLocation = try container.decodeIfPresent(Bool.self, forKey: .isFromCurrentLocation) ?? false
    }

    // MARK: - Coding Keys
    
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

// MARK: - TripLeg Helpers

private extension TripLeg {
    /// Convert a bullet-pointed string into an array of highlights
    /// Handles multiple bullet formats: •, *, -, –, —
    /// Also handles newline-separated lists
    static func normalizeHighlights(from rawString: String) -> [String] {
        var normalized = rawString.replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Replace various bullet tokens with newlines
        let bulletTokens = ["•", "*", "- ", "– ", "— "]
        for token in bulletTokens {
            normalized = normalized.replacingOccurrences(of: token, with: "\n")
        }

        // Split on newlines and clean up
        let components = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // If we got no components but have text, treat whole string as one highlight
        if components.isEmpty, !normalized.isEmpty {
            return [normalized]
        }

        return components.isEmpty ? [] : components
    }
}

// MARK: - Preview Data

#if DEBUG
extension TripLeg {
    /// Sample preview data for SwiftUI previews and testing
    /// Represents a 4-leg trip from New Braunfels through Texas to Oklahoma City
    static let previewData: [TripLeg] = {
        // Define all locations
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

        // Build trip legs
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
                isFromCurrentLocation: true  // This is the next leg from current location
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
    /// Sample preview data for SwiftUI previews and testing
    /// Represents a stay in New Braunfels
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
