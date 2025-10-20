import Combine
import Foundation

@MainActor
final class ParksViewModel: ObservableObject {
    enum MembershipFilter: Identifiable, Equatable {
        case all
        case membership(Park.Membership)

        var id: String {
            switch self {
            case .all:
                return "all"
            case let .membership(membership):
                return membership.rawValue
            }
        }

        var displayName: String {
            switch self {
            case .all:
                return "All Memberships"
            case let .membership(membership):
                return membership.rawValue
            }
        }

        static func == (lhs: MembershipFilter, rhs: MembershipFilter) -> Bool {
            switch (lhs, rhs) {
            case (.all, .all):
                return true
            case let (.membership(lhsValue), .membership(rhsValue)):
                return lhsValue == rhsValue
            default:
                return false
            }
        }
    }

    enum SortOption: String, CaseIterable, Identifiable {
        case familyRating
        case communityRating
        case name

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .familyRating:
                return "Family rating"
            case .communityRating:
                return "Community rating"
            case .name:
                return "Name"
            }
        }
    }

    @Published private(set) var parks: [Park]
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: Error?
    @Published private(set) var hasLoadedParks: Bool
    @Published var selectedFilter: MembershipFilter = .all
    @Published var showFamilyFavoritesOnly = false
    @Published var selectedState: String?
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .familyRating

    private let parksService: ParksService

    init(parks: [Park] = [], parksService: ParksService = ParksService()) {
        self.parks = parks
        self.parksService = parksService
        self.hasLoadedParks = !parks.isEmpty
        self.loadError = nil
    }

    func loadParks(forceReload: Bool = false) async {
        guard !isLoading else { return }
        if hasLoadedParks && !forceReload { return }

        isLoading = true
        loadError = nil

        do {
            let parks = try await parksService.fetchParks()
            self.parks = parks
            hasLoadedParks = true
        } catch {
            loadError = error
        }

        isLoading = false
    }

    var availableStates: [String] {
        let states = Set(parks.map { $0.state })
        return states.sorted()
    }

    var membershipFilters: [MembershipFilter] {
        let memberships = Set(parks.flatMap { $0.memberships })
        let sortedMemberships = memberships.sorted { $0.rawValue < $1.rawValue }
        return [.all] + sortedMemberships.map { MembershipFilter.membership($0) }
    }

    var filteredParks: [Park] {
        parks
            .filter { matchesMembershipFilter($0) }
            .filter { matchesRatingFilter($0) }
            .filter { matchesStateFilter($0) }
            .filter { matchesSearch($0) }
            .sorted(by: sortComparator)
    }

    func makeDetailViewModel(for park: Park) -> ParkDetailViewModel {
        ParkDetailViewModel(parkID: park.id,
                            initialSummary: park,
                            service: parksService) { [weak self] updatedPark in
            self?.replacePark(with: updatedPark)
        }
    }

    func replacePark(with park: Park) {
        if let index = parks.firstIndex(where: { $0.id == park.id }) {
            parks[index] = park
        } else {
            parks.append(park)
        }
    }

    private func matchesStateFilter(_ park: Park) -> Bool {
        guard let selectedState else { return true }
        return park.state == selectedState
    }

    private func matchesMembershipFilter(_ park: Park) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case let .membership(membership):
            return park.memberships.contains(membership)
        }
    }

    private func matchesRatingFilter(_ park: Park) -> Bool {
        guard showFamilyFavoritesOnly else { return true }
        return park.rating >= 4.0
    }

    private func matchesSearch(_ park: Park) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let needle = trimmed.lowercased()
        let haystacks = [park.name, park.city, park.state]
        return haystacks.contains { $0.lowercased().contains(needle) }
    }

    private func sortComparator(_ lhs: Park, _ rhs: Park) -> Bool {
        switch sortOption {
        case .familyRating:
            if lhs.familyRating == rhs.familyRating {
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
            return lhs.familyRating > rhs.familyRating
        case .communityRating:
            let lhsCommunity = lhs.communityRating ?? -1
            let rhsCommunity = rhs.communityRating ?? -1
            if lhsCommunity == rhsCommunity {
                if lhs.familyRating == rhs.familyRating {
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
                return lhs.familyRating > rhs.familyRating
            }
            return lhsCommunity > rhsCommunity
        case .name:
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }
}
