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
        .store(in: &cancellables)
    }

    private func fetchParks() {
        fetchTask?.cancel()

        let trimmedSearch = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSearch = trimmedSearch.isEmpty ? nil : trimmedSearch
        let normalizedState = selectedState?.trimmingCharacters(in: .whitespacesAndNewlines)
        let membershipParameter: Park.Membership?
        switch selectedFilter {
        case .all:
            membershipParameter = nil
        case let .membership(value):
            membershipParameter = value
        }
        let minimumRating = showFamilyFavoritesOnly ? 4.0 : nil

        fetchTask = Task { [weak self] in
            guard let self else { return }

            self.isLoading = true
            self.error = nil

            do {
                let response = try await service.fetchParks(
                    search: normalizedSearch,
                    state: normalizedState?.isEmpty == true ? nil : normalizedState,
                    membership: membershipParameter,
                    minRating: minimumRating
                )

                self.filteredParks = response.parks
                self.availableStates = response.availableStates
                self.availableMemberships = response.availableMemberships
                self.membershipFilters = [.all] + response.availableMemberships.map { MembershipFilter.membership($0) }

                if let selectedState = self.selectedState,
                   !response.availableStates.contains(selectedState) {
                    self.selectedState = nil
                }

                if case let .membership(current) = self.selectedFilter,
                   !response.availableMemberships.contains(current) {
                    self.selectedFilter = .all
                }

                self.isLoading = false
            } catch {
                guard !Task.isCancelled else { return }
                self.filteredParks = []
                self.isLoading = false
                self.error = error.localizedDescription
            }
        }
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
