import Foundation

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

    @Published var parks: [Park]
    @Published var selectedFilter: MembershipFilter = .all
    @Published var showFamilyFavoritesOnly = false

    init(parks: [Park] = Park.sampleData) {
        self.parks = parks
    }

    var filteredParks: [Park] {
        parks.filter { park in
            matchesMembershipFilter(park) && matchesRatingFilter(park)
        }
        .sorted { lhs, rhs in
            if showFamilyFavoritesOnly {
                return lhs.rating == rhs.rating ? lhs.name < rhs.name : lhs.rating > rhs.rating
            } else {
                return lhs.name < rhs.name
            }
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
}
