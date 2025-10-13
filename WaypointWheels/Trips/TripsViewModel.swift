import Foundation

@MainActor
final class TripsViewModel: ObservableObject {
    @Published private(set) var itinerary: [TripLeg]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugPayload: String?

    private let service: TripsService
    private var hasLoaded: Bool

    init(service: TripsService = TripsService(), initialItinerary: [TripLeg] = []) {
        self.service = service
        self.itinerary = initialItinerary
        self.debugPayload = nil
        self.hasLoaded = !initialItinerary.isEmpty
    }

    func loadItinerary(forceReload: Bool = false) async {
        if isLoading { return }
        if hasLoaded && !forceReload { return }

        isLoading = true
        errorMessage = nil
        debugPayload = nil

        do {
            let result = try await service.fetchCurrentItineraryResult()
            itinerary = result.legs
            debugPayload = result.rawResponse
            hasLoaded = true
        } catch let serviceError as TripsService.TripsError {
            debugPayload = serviceError.rawBody
            errorMessage = serviceError.userFacingMessage
        } catch {
            errorMessage = error.userFacingMessage
        }

        isLoading = false
    }

    func removeLeg(_ leg: TripLeg) {
        itinerary.removeAll { $0.id == leg.id }
    }
}
