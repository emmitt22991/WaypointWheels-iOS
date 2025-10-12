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

    @Published private(set) var filteredParks: [Park] = []
    @Published private(set) var availableStates: [String] = []
    @Published private(set) var availableMemberships: [Park.Membership] = []
    @Published private(set) var membershipFilters: [MembershipFilter] = [.all]

    @Published var searchQuery: String = ""
    @Published var selectedState: String?
    @Published var selectedFilter: MembershipFilter = .all
    @Published var showFamilyFavoritesOnly = false
    @Published var isLoading: Bool = false
    @Published var error: String?

    private let service: ParksService
    private var cancellables = Set<AnyCancellable>()
    private var fetchTask: Task<Void, Never>?

    init(service: ParksService = ParksService()) {
        self.service = service
        configureBindings()
        fetchParks()
    }

    private func configureBindings() {
        Publishers.CombineLatest4(
            $searchQuery.removeDuplicates(),
            $selectedState.removeDuplicates(),
            $selectedFilter.removeDuplicates(),
            $showFamilyFavoritesOnly.removeDuplicates()
        )
        .dropFirst()
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .sink { [weak self] _ in
            self?.fetchParks()
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
}
