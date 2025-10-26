import Foundation

final class TripsService {
    struct ItineraryResult: Equatable {
        let legs: [TripLeg]
        let currentLocation: CurrentLocation?
        let rawResponse: String?
    }

    enum TripsError: LocalizedError, Equatable {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse(rawBody: String?)
        case serverError(message: String, rawBody: String?)
        case noActiveTrip

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Missing API base URL configuration."
            case let .invalidBaseURL(value):
                return "Invalid API base URL: \(value)."
            case .invalidResponse:
                return "Unexpected response from the trips endpoint."
            case let .serverError(message, _):
                return message
            case .noActiveTrip:
                return "No active trip is scheduled."
            }
        }

        var rawBody: String? {
            switch self {
            case let .invalidResponse(rawBody):
                return rawBody
            case let .serverError(_, rawBody):
                return rawBody
            default:
                return nil
            }
        }
        
        var userFacingMessage: String {
            errorDescription ?? "An unexpected error occurred."
        }
    }

    struct ItineraryResponse: Decodable, EmptyDecodable {
        let legs: [TripLeg]
        let currentLocation: CurrentLocation?

        init() {
            self.legs = []
            self.currentLocation = nil
        }

        init(from decoder: Decoder) throws {
            print("📦 TripsService: Decoding ItineraryResponse...")
            
            // Some responses return an array of legs at the root level.
            if let singleValueContainer = try? decoder.singleValueContainer(),
               let legs = try? singleValueContainer.decode([TripLeg].self) {
                print("✅ TripsService: Decoded legs from root array (count: \(legs.count))")
                self.legs = legs
                self.currentLocation = nil
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Try to decode legs from direct "legs" key
            if let legs = try? container.decode([TripLeg].self, forKey: .legs) {
                print("✅ TripsService: Decoded \(legs.count) legs from 'legs' key")
                self.legs = legs
                
                // Try to decode current_location
                if let currentLoc = try? container.decode(CurrentLocation.self, forKey: .currentLocation) {
                    print("✅ TripsService: Decoded current location: \(currentLoc.parkName)")
                    self.currentLocation = currentLoc
                } else {
                    print("ℹ️ TripsService: No current_location in response")
                    self.currentLocation = nil
                }
                return
            }

            // Try nested structures
            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .trip) {
                print("✅ TripsService: Decoded \(legs.count) legs from 'trip' nested key")
                self.legs = legs
                self.currentLocation = try? container.decode(CurrentLocation.self, forKey: .currentLocation)
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .itinerary) {
                print("✅ TripsService: Decoded \(legs.count) legs from 'itinerary' nested key")
                self.legs = legs
                self.currentLocation = try? container.decode(CurrentLocation.self, forKey: .currentLocation)
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .currentTrip) {
                print("✅ TripsService: Decoded \(legs.count) legs from 'current_trip' nested key")
                self.legs = legs
                self.currentLocation = try? container.decode(CurrentLocation.self, forKey: .currentLocation)
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .data) {
                print("✅ TripsService: Decoded \(legs.count) legs from 'data' nested key")
                self.legs = legs
                self.currentLocation = try? container.decode(CurrentLocation.self, forKey: .currentLocation)
                return
            }

            // Check if payload is empty
            if ItineraryResponse.payloadIsEmpty(decoder: decoder) {
                print("ℹ️ TripsService: Empty payload, returning empty legs")
                self.legs = []
                self.currentLocation = nil
                return
            }

            print("❌ TripsService: Unable to decode legs from any known structure")
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath,
                                                    debugDescription: "Unable to decode itinerary legs from response."))
        }

        private static func decodeNestedLegs(from container: KeyedDecodingContainer<CodingKeys>,
                                             forKey key: CodingKeys) throws -> [TripLeg]? {
            guard container.contains(key) else { return nil }
            let nestedContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: key)

            if let legs = try? nestedContainer.decode([TripLeg].self, forKey: .legs) {
                return legs
            }

            for nestedKey in CodingKeys.nestedContainers {
                if let deeperLegs = try decodeNestedLegs(from: nestedContainer, forKey: nestedKey) {
                    return deeperLegs
                }
            }

            return nil
        }

        private static func payloadIsEmpty(decoder: Decoder) -> Bool {
            guard let container = try? decoder.container(keyedBy: AnyCodingKey.self) else { return false }
            return container.allKeys.isEmpty
        }

        private enum CodingKeys: String, CodingKey {
            case legs
            case currentLocation = "current_location"
            case trip
            case itinerary
            case data
            case timeline
            case currentTrip = "current_trip"

            static let nestedContainers: [CodingKeys] = [.trip, .itinerary, .currentTrip, .data, .timeline]
        }

        private struct AnyCodingKey: CodingKey {
            let stringValue: String
            let intValue: Int?

            init?(stringValue: String) {
                self.stringValue = stringValue
                self.intValue = nil
            }

            init?(intValue: Int) {
                self.stringValue = "\(intValue)"
                self.intValue = intValue
            }
        }
    }

    private let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) {
        self.apiClient = apiClient
    }

    func fetchCurrentItineraryResult() async throws -> ItineraryResult {
        do {
            // Debug: Print the full URL being requested
            print("🔍 TripsService: Fetching trip itinerary from API...")
            print("🔍 TripsService: Attempting path: trips/itinerary.php")
            
            // Build the URL to see what we're actually calling
            do {
                let testURL = try apiClient.url(for: "trips/itinerary.php")
                print("🔍 TripsService: Full URL will be: \(testURL.absoluteString)")
            } catch {
                print("❌ TripsService: Error building URL: \(error)")
            }
            
            // Use the itinerary endpoint which converts timeline to legs format
            let response: APIClient.APIResponse<Data> = try await apiClient.request(path: "trips/itinerary.php", method: "GET")
            
            // Debug: Print response status
            print("✅ TripsService: API Response received")
            if let rawString = response.rawString {
                print("📄 TripsService: Raw response length: \(rawString.count) characters")
                // Print first 500 characters for debugging
                let preview = rawString.prefix(500)
                print("📄 TripsService: Raw response preview: \(preview)")
            } else {
                print("📄 TripsService: Raw response: (empty or binary)")
            }
            
            do {
                let itinerary = try apiClient.decode(ItineraryResponse.self, from: response.value)
                
                // Log what we decoded
                print("✅ TripsService: Successfully decoded response")
                print("📊 TripsService: Legs count: \(itinerary.legs.count)")
                if let currentLoc = itinerary.currentLocation {
                    print("📍 TripsService: Current location: \(currentLoc.parkName)")
                    print("📍 TripsService: Current location description: \(currentLoc.description)")
                    print("📍 TripsService: Current location dates: \(currentLoc.arrivalDate ?? "nil") to \(currentLoc.departureDate ?? "nil")")
                } else {
                    print("ℹ️ TripsService: No current location in response")
                }
                
                // Ensure each leg has a valid ID and log details
                let legsWithIDs = itinerary.legs.enumerated().map { index, leg in
                    print("📋 TripsService: Leg \(index): \(leg.start.name) → \(leg.end.name)")
                    print("   - Day label: \(leg.dayLabel)")
                    print("   - Date: \(leg.dateRangeDescription)")
                    print("   - Distance: \(String(format: "%.1f", leg.distanceInMiles)) miles")
                    print("   - Drive time: \(leg.estimatedDriveTime)")
                    print("   - From current location: \(leg.isFromCurrentLocation)")
                    
                    if leg.id.isEmpty {
                        let newLeg = TripLeg(
                            id: "leg-\(index + 1)",
                            dayLabel: leg.dayLabel,
                            dateRangeDescription: leg.dateRangeDescription,
                            start: leg.start,
                            end: leg.end,
                            distanceInMiles: leg.distanceInMiles,
                            estimatedDriveTime: leg.estimatedDriveTime,
                            highlights: leg.highlights,
                            notes: leg.notes,
                            isFromCurrentLocation: leg.isFromCurrentLocation
                        )
                        print("   ⚠️ TripsService: Generated ID for leg: leg-\(index + 1)")
                        return newLeg
                    }
                    return leg
                }
                
                print("✅ TripsService: Successfully processed \(legsWithIDs.count) trip legs")
                return ItineraryResult(
                    legs: legsWithIDs,
                    currentLocation: itinerary.currentLocation,
                    rawResponse: response.rawString
                )
            } catch is DecodingError {
                // Check if response is HTML (404/401 page)
                if let rawString = response.rawString,
                   rawString.contains("<!DOCTYPE") || rawString.contains("<html") {
                    
                    // Check for authentication error
                    if rawString.lowercased().contains("authentication required") {
                        print("❌ TripsService: Authentication required - please log in")
                        throw TripsError.serverError(
                            message: "Please sign in to view your trips.",
                            rawBody: rawString
                        )
                    }
                    
                    print("❌ TripsService: Received HTML instead of JSON - likely wrong endpoint URL")
                    throw TripsError.serverError(
                        message: "API endpoint not found. Please check your configuration.",
                        rawBody: rawString
                    )
                }
                
                print("❌ TripsService: Failed to decode JSON response")
                if let rawString = response.rawString {
                    print("📄 TripsService: Response preview: \(rawString.prefix(500))")
                }
                throw TripsError.invalidResponse(rawBody: response.rawString)
            }
        } catch let error as TripsError {
            print("❌ TripsService: TripsError: \(error.localizedDescription)")
            throw error
        } catch let error as APIClient.APIError {
            print("❌ TripsService: APIError: \(error)")
            let tripsError = TripsError(apiError: error)
            
            // Check if this is an authentication error
            if case let .serverError(message, body) = tripsError {
                // Check for authentication-related errors
                if message.lowercased().contains("authentication required") ||
                   message.lowercased().contains("authentication") ||
                   body?.lowercased().contains("authentication required") == true {
                    print("❌ TripsService: Throwing authentication error")
                    throw TripsError.serverError(
                        message: "Please sign in to view your trips.",
                        rawBody: body
                    )
                }
                
                // Check if this is a "no active trip" error (404 or specific message)
                if message.lowercased().contains("no active trip") {
                    print("ℹ️ TripsService: No active trip found")
                    throw TripsError.noActiveTrip
                }
            }
            
            throw tripsError
        } catch {
            print("❌ TripsService: Unexpected error: \(error)")
            throw TripsError.invalidResponse(rawBody: nil)
        }
    }

    func fetchCurrentItinerary() async throws -> [TripLeg] {
        let result = try await fetchCurrentItineraryResult()
        return result.legs
    }
}

private extension TripsService.TripsError {
    init(apiError: APIClient.APIError) {
        switch apiError {
        case .missingConfiguration:
            self = .missingConfiguration
        case let .invalidBaseURL(value):
            self = .invalidBaseURL(value)
        case .invalidResponse:
            self = .invalidResponse(rawBody: nil)
        case let .serverError(message, body):
            // Check for 404 "no active trip" case
            if message.lowercased().contains("no active trip") {
                self = .noActiveTrip
            } else {
                self = .serverError(message: message, rawBody: body)
            }
        }
    }
}
