import Foundation

@MainActor
final class ParksViewModel: ObservableObject {
    enum MembershipFilter: Identifiable, CaseIterable {
        case all
        case membership(Park.Membership)

        var id: String {
            switch self {
            case .all:
                return "all"
            case .membership(let membership):
                return membership.rawValue
            }
        }

        var displayName: String {
            switch self {
            case .all:
                return "All Memberships"
            case .membership(let membership):
                return membership.rawValue
            }
        }

        static var allCases: [ParksViewModel.MembershipFilter] {
            [.all] + Park.Membership.allCases.map { .membership($0) }
        }
    }

    @Published private(set) var parks: [Park]
    @Published var selectedFilter: MembershipFilter = .all
    @Published var showFamilyFavoritesOnly = false
    @Published var selectedState: String?
    @Published var searchText: String = ""

    private let parksService: ParksService

    init(parks: [Park] = Park.sampleData, parksService: ParksService = ParksService()) {
        self.parks = parks
        self.parksService = parksService
    }

    var availableStates: [String] {
        let states = Set(parks.map { $0.state })
        return states.sorted()
    }

    var filteredParks: [Park] {
        parks
            .filter { matchesMembershipFilter($0) }
            .filter { matchesRatingFilter($0) }
            .filter { matchesStateFilter($0) }
            .filter { matchesSearch($0) }
            .sorted { lhs, rhs in
                if showFamilyFavoritesOnly {
                    return lhs.rating == rhs.rating ? lhs.name < rhs.name : lhs.rating > rhs.rating
                } else {
                    return lhs.name < rhs.name
                }
            }
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

    private func matchesMembershipFilter(_ park: Park) -> Bool {
        switch selectedFilter {
        case .all:
            return true
        case .membership(let membership):
            return park.memberships.contains(membership)
        }
    }

    private func matchesRatingFilter(_ park: Park) -> Bool {
        guard showFamilyFavoritesOnly else { return true }
        return park.rating >= 4.0
    }

    private func matchesStateFilter(_ park: Park) -> Bool {
        guard let selectedState else { return true }
        return park.state == selectedState
    }

    private func matchesSearch(_ park: Park) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let needle = trimmed.lowercased()
        let haystacks = [park.name, park.city, park.state]
        return haystacks.contains { $0.lowercased().contains(needle) }
    }
}
