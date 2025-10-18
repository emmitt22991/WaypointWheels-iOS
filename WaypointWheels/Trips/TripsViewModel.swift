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
        
        // Debug: Check auth status
        #if DEBUG
        checkAuthStatus()
        #endif

        do {
            let result = try await service.fetchCurrentItineraryResult()
            itinerary = result.legs
            cacheDebugPayload(result.rawResponse)
            hasLoaded = true
            
            // Clear any previous errors if successful
            errorMessage = nil
        } catch let serviceError as TripsService.TripsError {
            cacheDebugPayload(serviceError.rawBody)
            
            // Handle "no active trip" specially - don't show error, just empty state
            if case .noActiveTrip = serviceError {
                itinerary = []
                hasLoaded = true
                errorMessage = nil
            } else {
                errorMessage = serviceError.userFacingMessage
            }
        } catch {
            // Handle other errors
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                errorMessage = description
            } else {
                errorMessage = "An unexpected error occurred."
            }
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
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    private func checkAuthStatus() {
        print("🔐 Checking authentication status...")
        
        let keychainStore = KeychainStore()
        do {
            if let token = try keychainStore.fetchToken() {
                if token.isEmpty {
                    print("❌ Token is empty")
                } else {
                    print("✅ Token exists (length: \(token.count))")
                    
                    if token.components(separatedBy: ".").count == 3 {
                        print("✅ Token appears to be a valid JWT format")
                    } else {
                        print("⚠️ Token doesn't look like a JWT")
                    }
                }
            } else {
                print("❌ No token found in keychain")
                print("💡 User needs to log in first")
            }
        } catch {
            print("❌ Error reading token from keychain: \(error)")
        }
    }
    #endif
}
