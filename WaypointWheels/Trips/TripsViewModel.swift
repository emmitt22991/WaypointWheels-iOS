import Foundation

@MainActor
final class TripsViewModel: ObservableObject {
    @Published private(set) var itinerary: [TripLeg]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var errorResponseBody: String?

    private let service: TripsService
    private var hasLoaded: Bool

    init(service: TripsService = TripsService(), initialItinerary: [TripLeg] = []) {
        self.service = service
        self.itinerary = initialItinerary
        self.hasLoaded = !initialItinerary.isEmpty
        self.errorResponseBody = nil
    }

    func loadItinerary(forceReload: Bool = false) async {
        if isLoading { return }
        if hasLoaded && !forceReload { return }

        isLoading = true
        errorMessage = nil
        errorResponseBody = nil

        do {
            itinerary = try await service.fetchCurrentItinerary()
            hasLoaded = true
            errorResponseBody = nil
        } catch {
            errorMessage = error.userFacingMessage
            if let tripsError = error as? TripsService.TripsError {
                errorResponseBody = tripsError.responseBody
            } else {
                errorResponseBody = nil
            }
        }

        isLoading = false
    }

    func removeLeg(_ leg: TripLeg) {
        itinerary.removeAll { $0.id == leg.id }
    }
}
