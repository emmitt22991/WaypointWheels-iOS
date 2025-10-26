import Foundation

@MainActor
final class TripsViewModel: ObservableObject {
    @Published private(set) var itinerary: [TripLeg]
    @Published private(set) var currentLocation: CurrentLocation?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var debugPayload: String?
    @Published private(set) var debugPayloadCache: String?

    private let service: TripsService
    private var hasLoaded: Bool

    init(service: TripsService = TripsService(), initialItinerary: [TripLeg] = [], initialCurrentLocation: CurrentLocation? = nil) {
        print("🔧 TripsViewModel: Initializing...")
        self.service = service
        self.itinerary = initialItinerary
        self.currentLocation = initialCurrentLocation
        self.debugPayload = nil
        self.debugPayloadCache = nil
        self.hasLoaded = !initialItinerary.isEmpty
        
        print("🔧 TripsViewModel: Initialized with \(initialItinerary.count) legs")
        if let currentLoc = initialCurrentLocation {
            print("📍 TripsViewModel: Initial current location: \(currentLoc.parkName)")
        }
    }

    func loadItinerary(forceReload: Bool = false) async {
        print("📥 TripsViewModel: loadItinerary called (forceReload: \(forceReload))")
        
        if isLoading {
            print("⚠️ TripsViewModel: Already loading, skipping...")
            return
        }
        if hasLoaded && !forceReload {
            print("ℹ️ TripsViewModel: Already loaded and not forcing reload, skipping...")
            return
        }

        isLoading = true
        errorMessage = nil
        cacheDebugPayload(nil)
        
        print("🔍 TripsViewModel: Starting itinerary load...")
        
        // Debug: Check auth status
        #if DEBUG
        checkAuthStatus()
        #endif

        do {
            print("🌐 TripsViewModel: Calling service.fetchCurrentItineraryResult()...")
            let result = try await service.fetchCurrentItineraryResult()
            
            print("✅ TripsViewModel: Received result from service")
            print("📊 TripsViewModel: Legs count: \(result.legs.count)")
            
            itinerary = result.legs
            currentLocation = result.currentLocation
            cacheDebugPayload(result.rawResponse)
            hasLoaded = true
            
            // Clear any previous errors if successful
            errorMessage = nil
            
            // Log details about what was loaded
            if let currentLoc = currentLocation {
                print("📍 TripsViewModel: Current location set: \(currentLoc.parkName)")
                print("📍 TripsViewModel: Current location description: \(currentLoc.description)")
                print("📍 TripsViewModel: Current location date range: \(currentLoc.dateRangeDisplay)")
            } else {
                print("ℹ️ TripsViewModel: No current location in response")
            }
            
            for (index, leg) in itinerary.enumerated() {
                print("📋 TripsViewModel: Leg \(index): \(leg.dayLabel) - \(leg.start.name) → \(leg.end.name)")
                print("   - Date: \(leg.dateRangeDescription)")
                print("   - Distance: \(String(format: "%.1f", leg.distanceInMiles)) miles")
                print("   - From current location: \(leg.isFromCurrentLocation)")
            }
            
            print("✅ TripsViewModel: Itinerary loaded successfully")
            
        } catch let serviceError as TripsService.TripsError {
            print("❌ TripsViewModel: TripsError caught: \(serviceError.localizedDescription)")
            cacheDebugPayload(serviceError.rawBody)
            
            // Handle "no active trip" specially - don't show error, just empty state
            if case .noActiveTrip = serviceError {
                print("ℹ️ TripsViewModel: No active trip - showing empty state")
                itinerary = []
                currentLocation = nil
                hasLoaded = true
                errorMessage = nil
            } else {
                print("❌ TripsViewModel: Setting error message: \(serviceError.userFacingMessage)")
                errorMessage = serviceError.userFacingMessage
            }
        } catch {
            print("❌ TripsViewModel: Unexpected error: \(error)")
            // Handle other errors
            if let localizedError = error as? LocalizedError,
               let description = localizedError.errorDescription {
                print("❌ TripsViewModel: Localized error description: \(description)")
                errorMessage = description
            } else {
                print("❌ TripsViewModel: Generic error, using default message")
                errorMessage = "An unexpected error occurred."
            }
        }

        isLoading = false
        print("📥 TripsViewModel: loadItinerary completed (isLoading: false)")
    }

    func removeLeg(_ leg: TripLeg) {
        print("🗑️ TripsViewModel: Removing leg: \(leg.id)")
        print("   - From: \(leg.start.name)")
        print("   - To: \(leg.end.name)")
        
        let countBefore = itinerary.count
        itinerary.removeAll { $0.id == leg.id }
        let countAfter = itinerary.count
        
        print("✅ TripsViewModel: Leg removed. Count before: \(countBefore), after: \(countAfter)")
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
        print("🔐 TripsViewModel: Checking authentication status...")
        
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
