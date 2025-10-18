import Foundation

final class TripsService {
    struct ItineraryResult: Equatable {
        let legs: [TripLeg]
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

        init() {
            self.legs = []
        }

        init(from decoder: Decoder) throws {
            // Some responses return an array of legs at the root level.
            if let singleValueContainer = try? decoder.singleValueContainer(),
               let legs = try? singleValueContainer.decode([TripLeg].self) {
                self.legs = legs
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)

            if let legs = try? container.decode([TripLeg].self, forKey: .legs) {
                self.legs = legs
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .trip) {
                self.legs = legs
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .itinerary) {
                self.legs = legs
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .currentTrip) {
                self.legs = legs
                return
            }

            if let legs = try ItineraryResponse.decodeNestedLegs(from: container, forKey: .data) {
                self.legs = legs
                return
            }

            if ItineraryResponse.payloadIsEmpty(decoder: decoder) {
                self.legs = []
                return
            }

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
            case trip
            case itinerary
            case data
            case currentTrip = "current_trip"

            static let nestedContainers: [CodingKeys] = [.trip, .itinerary, .currentTrip, .data]
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
            print("🔍 Fetching current trip from API...")
            print("📍 Attempting path: trips/current/")
            
            // Build the URL to see what we're actually calling
            do {
                let testURL = try apiClient.url(for: "trips/current/")
                print("📍 Full URL will be: \(testURL.absoluteString)")
            } catch {
                print("❌ Error building URL: \(error)")
            }
            
            // Path: trips/current/ (base URL already includes /api)
            let response: APIClient.APIResponse<Data> = try await apiClient.request(path: "trips/current/", method: "GET")
            
            // Debug: Print response status
            print("✅ API Response received")
            print("📄 Raw response: \(response.rawString ?? "nil")")
            
            do {
                let itinerary = try apiClient.decode(ItineraryResponse.self, from: response.value)
                
                // Ensure each leg has a valid ID
                let legsWithIDs = itinerary.legs.enumerated().map { index, leg in
                    if leg.id.isEmpty {
                        return TripLeg(
                            id: "leg-\(index + 1)",
                            dayLabel: leg.dayLabel,
                            dateRangeDescription: leg.dateRangeDescription,
                            start: leg.start,
                            end: leg.end,
                            distanceInMiles: leg.distanceInMiles,
                            estimatedDriveTime: leg.estimatedDriveTime,
                            highlights: leg.highlights,
                            notes: leg.notes
                        )
                    }
                    return leg
                }
                
                print("✅ Successfully decoded \(legsWithIDs.count) trip legs")
                return ItineraryResult(legs: legsWithIDs, rawResponse: response.rawString)
            } catch is DecodingError {
                // Check if response is HTML (404/401 page)
                if let rawString = response.rawString,
                   rawString.contains("<!DOCTYPE") || rawString.contains("<html") {
                    
                    // Check for authentication error
                    if rawString.lowercased().contains("authentication required") {
                        print("❌ Authentication required - please log in")
                        throw TripsError.serverError(
                            message: "Please sign in to view your trips.",
                            rawBody: rawString
                        )
                    }
                    
                    print("❌ Received HTML instead of JSON - likely wrong endpoint URL")
                    throw TripsError.serverError(
                        message: "API endpoint not found. Please check your configuration.",
                        rawBody: rawString
                    )
                }
                print("❌ Failed to decode response")
                throw TripsError.invalidResponse(rawBody: response.rawString)
            }
        } catch let error as TripsError {
            throw error
        } catch let error as APIClient.APIError {
            let tripsError = TripsError(apiError: error)
            
            // Check if this is an authentication error
            if case let .serverError(message, body) = tripsError {
                // Check for authentication-related errors
                if message.lowercased().contains("authentication required") ||
                   message.lowercased().contains("authentication") ||
                   body?.lowercased().contains("authentication required") == true {
                    throw TripsError.serverError(
                        message: "Please sign in to view your trips.",
                        rawBody: body
                    )
                }
                
                // Check if this is a "no active trip" error (404 or specific message)
                if message.lowercased().contains("no active trip") {
                    throw TripsError.noActiveTrip
                }
            }
            
            throw tripsError
        } catch {
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
