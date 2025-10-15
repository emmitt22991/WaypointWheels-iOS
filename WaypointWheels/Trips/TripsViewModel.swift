import Foundation

@MainActor
final class TripsViewModel: ObservableObject {
    @Published private(set) var itinerary: [TripLeg]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugPayload: String?
    @Published private(set) var debugPayloadCache: String?

    private let service: TripsService
    private var hasLoaded: Bool

    init(service: TripsService = TripsService(), initialItinerary: [TripLeg] = []) {
        self.service = service
        self.itinerary = initialItinerary
        self.debugPayload = nil
        self.debugPayloadCache = nil
        self.hasLoaded = !initialItinerary.isEmpty
    }

    func loadItinerary(forceReload: Bool = false) async {
        if isLoading { return }
        if hasLoaded && !forceReload { return }

        isLoading = true
        errorMessage = nil
        cacheDebugPayload(nil)

        do {
            let result = try await service.fetchCurrentItineraryResult()
            itinerary = result.legs
            cacheDebugPayload(result.rawResponse)
            hasLoaded = true
        } catch let serviceError as TripsService.TripsError {
            cacheDebugPayload(serviceError.rawBody)
            errorMessage = serviceError.userFacingMessage
        } catch {
            errorMessage = error.userFacingMessage
        }

        isLoading = false
    }

    func removeLeg(_ leg: TripLeg) {
        itinerary.removeAll { $0.id == leg.id }
    }

    private func cacheDebugPayload(_ payload: String?) {
        debugPayload = payload

        guard let trimmed = payload?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            debugPayloadCache = nil
            return
        }

        debugPayloadCache = trimmed
    }
}
