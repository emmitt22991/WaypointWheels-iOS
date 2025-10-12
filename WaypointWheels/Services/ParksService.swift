import Foundation

struct ParksServiceResponse: Decodable {
    let parks: [Park]
    let availableStates: [String]
    let availableMemberships: [Park.Membership]

    private enum CodingKeys: String, CodingKey {
        case parks
        case availableStates = "available_states"
        case availableMemberships = "available_memberships"
    }

    init(parks: [Park], availableStates: [String], availableMemberships: [Park.Membership]) {
        self.parks = parks
        self.availableStates = availableStates
        self.availableMemberships = availableMemberships
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        parks = try container.decodeIfPresent([Park].self, forKey: .parks) ?? []
        availableStates = try container.decodeIfPresent([String].self, forKey: .availableStates) ?? []

        let rawMemberships = try container.decodeIfPresent([String].self, forKey: .availableMemberships) ?? []
        availableMemberships = rawMemberships.compactMap { Park.Membership(rawValue: $0) }
    }
}

final class ParksService {
    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    func fetchParks(search: String? = nil,
                    state: String? = nil,
                    membership: Park.Membership? = nil,
                    minRating: Double? = nil) async throws -> ParksServiceResponse {
        var queryItems: [URLQueryItem] = []
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let state, !state.isEmpty {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        if let membership {
            queryItems.append(URLQueryItem(name: "membership", value: membership.rawValue))
        }
        if let minRating {
            queryItems.append(URLQueryItem(name: "min_rating", value: String(minRating)))
        }

        return try await client.request(path: "/api/parks", queryItems: queryItems)
    }
}
