import Foundation

final class TripsService {
    enum TripsError: LocalizedError, Equatable {
        case missingConfiguration
        case invalidBaseURL(String)
        case invalidResponse
        case serverError(String)

        var errorDescription: String? {
            switch self {
            case .missingConfiguration:
                return "Missing API base URL configuration."
            case let .invalidBaseURL(value):
                return "Invalid API base URL: \(value)."
            case .invalidResponse:
                return "Unexpected response from the trips endpoint."
            case let .serverError(message):
                return message
            }
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

    func fetchCurrentItinerary() async throws -> [TripLeg] {
        do {
            let response: ItineraryResponse = try await apiClient.request(path: "trips/current/")
            return response.legs
        } catch let error as APIClient.APIError {
            throw TripsError(apiError: error)
        } catch is DecodingError {
            throw TripsError.invalidResponse
        } catch {
            throw TripsError.invalidResponse
        }
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
            self = .invalidResponse
        case let .serverError(message, _):
            self = .serverError(message)
        }
    }
}
