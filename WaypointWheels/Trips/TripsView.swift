import SwiftUI

@MainActor
struct TripsView: View {
    @StateObject private var viewModel: TripsViewModel
    @StateObject private var parksViewModel: ParksViewModel
    @State private var showDeleteConfirmation: TripLeg?
    // State for showing park detail when location name is tapped
    @State private var selectedParkForDetail: Park?
    @State private var parkSearchAlert: String?

    @MainActor
    init(viewModel: TripsViewModel? = nil, parksViewModel: ParksViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? TripsViewModel())
        _parksViewModel = StateObject(wrappedValue: parksViewModel ?? ParksViewModel(parksService: ParksService()))
        
        print("🏕️ TripsView: Initialized with viewModel and parksViewModel")
    }

    var body: some View {
        List {
            // Trip Plan button
            Section {
                NavigationLink {
                    TripPlanView(legs: viewModel.itinerary)
                } label: {
                    tripPlanButton
                }
                .listRowBackground(Color.clear)
            }
            .textCase(nil)

            // Current Location section (if available)
            if let currentLocation = viewModel.currentLocation {
                Section(header: Text("Current Location")) {
                    CurrentLocationCard(location: currentLocation)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .textCase(nil)
            }

            // Loading, error, or itinerary content
            if viewModel.isLoading {
                loadingState
            } else if let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else if viewModel.itinerary.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Upcoming Trips")) {
                    ForEach(Array(viewModel.itinerary.enumerated()), id: \.element.id) { index, leg in
                        TimelineRow(
                            leg: leg,
                            isFirst: index == 0,
                            isLast: index == viewModel.itinerary.count - 1,
                            onLocationTapped: { locationName in
                                // User tapped a location name in the timeline
                                // Search for a park matching that location name
                                print("🔍 TripsView: User tapped location: \(locationName)")
                                handleLocationTap(locationName: locationName)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                showDeleteConfirmation = leg
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.97, blue: 0.99), Color(red: 0.99, green: 0.95, blue: 0.90)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Trips")
        .confirmationDialog(
            "Remove this leg?",
            isPresented: Binding(
                get: { showDeleteConfirmation != nil },
                set: { newValue in
                    if !newValue { showDeleteConfirmation = nil }
                }
            ),
            presenting: showDeleteConfirmation
        ) { leg in
            Button("Delete Leg", role: .destructive) {
                withAnimation(.easeInOut) {
                    viewModel.removeLeg(leg)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { leg in
            Text("\(leg.start.name) to \(leg.end.name) will be removed from your route.")
        }
        .task {
            await viewModel.loadItinerary()
            // Load parks so we can search them when user taps location names
            await parksViewModel.loadParks()
        }
        .refreshable {
            await viewModel.loadItinerary(forceReload: true)
        }
        // Show park detail sheet when a park is found
        .sheet(item: $selectedParkForDetail) { park in
            NavigationStack {
                ParkDetailView(
                    parkID: park.id,
                    initialSummary: park,
                    service: ParksService(),
                    onParkUpdated: { updatedPark in
                        // Update the park in the parks list when ratings/reviews change
                        parksViewModel.replacePark(with: updatedPark)
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            selectedParkForDetail = nil
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        // Show alert if park not found
        .alert("Park Not Found", isPresented: Binding(
            get: { parkSearchAlert != nil },
            set: { if !$0 { parkSearchAlert = nil } }
        )) {
            Button("OK") {
                parkSearchAlert = nil
            }
        } message: {
            if let alertMessage = parkSearchAlert {
                Text(alertMessage)
            }
        }
    }
    
    // MARK: - Location Tap Handler
    
    /// Handle when user taps a location name in the timeline
    /// Searches for a park matching the location name and opens park detail
    private func handleLocationTap(locationName: String) {
        print("🔍 TripsView: Searching for park matching location: '\(locationName)'")
        
        // Extract just the park/city name from location strings like "Cherokee Landing" or "Nashville, TN"
        // Location names might be:
        // - Just park name: "Cherokee Landing"
        // - City, State: "Nashville, TN"
        // - Park name at City, State: "Cherokee Landing, Nashville, TN"
        
        let searchTerm = locationName.trimmingCharacters(in: .whitespaces)
        print("🔍 TripsView: Using search term: '\(searchTerm)'")
        
        // Search through all parks for a name match
        // Try exact match first, then case-insensitive contains
        let exactMatch = parksViewModel.parks.first { park in
            park.name.trimmingCharacters(in: .whitespaces).lowercased() == searchTerm.lowercased()
        }
        
        if let park = exactMatch {
            print("✅ TripsView: Found exact match park: \(park.name) (ID: \(park.id))")
            selectedParkForDetail = park
            return
        }
        
        // Try partial match on park name
        let partialMatch = parksViewModel.parks.first { park in
            park.name.lowercased().contains(searchTerm.lowercased())
        }
        
        if let park = partialMatch {
            print("✅ TripsView: Found partial match park: \(park.name) (ID: \(park.id))")
            selectedParkForDetail = park
            return
        }
        
        // If location is "City, State" format, try matching by city name
        let cityComponents = searchTerm.components(separatedBy: ",")
        if cityComponents.count >= 2 {
            let cityName = cityComponents[0].trimmingCharacters(in: .whitespaces)
            let stateCode = cityComponents[1].trimmingCharacters(in: .whitespaces)
            
            print("🔍 TripsView: Trying city/state match: city='\(cityName)', state='\(stateCode)'")
            
            let cityMatch = parksViewModel.parks.first { park in
                park.city.lowercased() == cityName.lowercased() &&
                park.state.lowercased() == stateCode.lowercased()
            }
            
            if let park = cityMatch {
                print("✅ TripsView: Found city/state match park: \(park.name) in \(park.city), \(park.state)")
                selectedParkForDetail = park
                return
            }
        }
        
        // No park found
        print("❌ TripsView: No park found matching '\(locationName)'")
        print("📊 TripsView: Total parks available to search: \(parksViewModel.parks.count)")
        
        // Show alert to user
        parkSearchAlert = "Could not find a park matching '\(locationName)'. The park may not be in the database yet, or the location name may not match exactly."
    }

    // MARK: - View Components

    private var tripPlanButton: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.23, blue: 0.52),
                                Color(red: 0.32, green: 0.29, blue: 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Image(systemName: "map.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("View Trip Plan")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))

                if !viewModel.itinerary.isEmpty {
                    Text("\(viewModel.itinerary.count) legs · \(totalMiles) miles")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Plan your next adventure")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color(red: 0.28, green: 0.23, blue: 0.52).opacity(0.15), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var totalMiles: String {
        let sum = viewModel.itinerary.reduce(0.0) { $0 + $1.distanceInMiles }
        return String(format: "%.0f", sum)
    }

    private var loadingState: some View {
        Section {
            HStack {
                Spacer()
                ProgressView("Loading your trip...")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .listRowBackground(Color.clear)
        }
    }

    private func errorState(message: String) -> some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Unable to load trip")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task {
                        await viewModel.loadItinerary(forceReload: true)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.28, green: 0.23, blue: 0.52))
            }
            .padding()
            .listRowBackground(Color.clear)
        }
    }

    private var emptyState: some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: "map")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text("No Trips Planned")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Start planning your next adventure!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
}

// MARK: - Current Location Card

private struct CurrentLocationCard: View {
    let location: CurrentLocation
    // State to show park detail sheet when card is tapped
    @State private var showingParkDetail = false
    
    var body: some View {
        // Make the entire card clickable
        Button {
            print("📍 CurrentLocationCard: User tapped current location card for: \(location.parkName)")
            showingParkDetail = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain) // Remove default button styling
        .sheet(isPresented: $showingParkDetail) {
            NavigationStack {
                ParkDetailDestination(location: location)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showingParkDetail = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
        }
    }
    
    private var cardContent: some View {
        HStack(alignment: .top, spacing: 16) {
            // Location icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.27, green: 0.64, blue: 0.56))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "location.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // "You are here" badge
                Text("You are here")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.27, green: 0.64, blue: 0.56))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(red: 0.27, green: 0.64, blue: 0.56).opacity(0.15))
                    .clipShape(Capsule())
                
                // Park name
                Text(location.parkName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                // Location description
                if !location.description.isEmpty {
                    Text(location.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Date range
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(location.dateRangeDisplay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Departure date (if available)
                if let departureDate = location.departureDate {
                    Divider()
                        .padding(.vertical, 4)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                        Text("Departing: \(Self.formatDepartureDate(departureDate))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // "Tap to add photos & reviews" hint
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                    Text("Tap to add photos & reviews")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color(red: 0.27, green: 0.64, blue: 0.56))
                .padding(.top, 4)
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.99, blue: 0.98),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(red: 0.27, green: 0.64, blue: 0.56).opacity(0.3), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods (Static)
    
    private static func formatDepartureDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Park Detail Destination Helper

private struct ParkDetailDestination: View {
    let location: CurrentLocation
    
    var body: some View {
        ParkDetailView(
            parkID: location.parkUuid,
            initialSummary: Park(
                id: location.parkUuid,
                name: location.parkName,
                state: Self.extractState(from: location.description),
                city: Self.extractCity(from: location.description),
                familyRating: 0.0,
                description: "",
                memberships: [],
                amenities: [],
                featuredNotes: []
            ),
            service: ParksService(),
            onParkUpdated: { _ in }
        )
    }
    
    // Helper to extract city from description like "Nashville, TN"
    private static func extractCity(from description: String) -> String {
        let parts = description.components(separatedBy: ",")
        return parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    // Helper to extract state from description like "Nashville, TN"
    private static func extractState(from description: String) -> String {
        let parts = description.components(separatedBy: ",")
        guard parts.count > 1 else { return "" }
        return parts[1].trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let leg: TripLeg
    let isFirst: Bool
    let isLast: Bool
    /// Callback when user taps a location name
    let onLocationTapped: (String) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(circleColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .padding(.bottom, 4)

                Rectangle()
                    .fill(Color(red: 0.75, green: 0.70, blue: 0.92).opacity(isLast ? 0 : 0.6))
                    .frame(width: 3)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 20)
            .padding(.top, isFirst ? 6 : 0)
            .padding(.bottom, isLast ? 20 : 0)

            // Trip leg content
            VStack(alignment: .leading, spacing: 8) {
                // Day label and date
                HStack(spacing: 10) {
                    Text(leg.dayLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(badgeColor)
                        .clipShape(Capsule())
                    Text(leg.dateRangeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Route - MAKE LOCATION NAMES CLICKABLE
                VStack(alignment: .leading, spacing: 6) {
                    // Display route with clickable location names
                    HStack(spacing: 4) {
                        // Start location - clickable
                        Button {
                            print("🗺️ TimelineRow: User tapped START location: \(leg.start.name)")
                            onLocationTapped(leg.start.name)
                        } label: {
                            Text(leg.start.name)
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                                .underline() // Visual cue that it's clickable
                        }
                        
                        // Arrow separator
                        Text("→")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        // End location - clickable
                        Button {
                            print("🗺️ TimelineRow: User tapped END location: \(leg.end.name)")
                            onLocationTapped(leg.end.name)
                        } label: {
                            Text(leg.end.name)
                                .font(.headline)
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                                .underline() // Visual cue that it's clickable
                        }
                    }
                    
                    // Distance and drive time (not clickable)
                    Text("\(String(format: "%.1f", leg.distanceInMiles)) miles · \(leg.estimatedDriveTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Highlights
                if !leg.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(leg.highlights, id: \.self) { highlight in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.32, green: 0.29, blue: 0.55))
                                    .padding(.top, 2)
                                Text(highlight)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Notes
                if let notes = leg.notes {
                    Divider()
                        .padding(.vertical, 4)
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.vertical, 8)
    }
    
    // Highlight the first trip (from current location) with a different color
    private var circleColor: Color {
        if leg.isFromCurrentLocation {
            return Color(red: 0.27, green: 0.64, blue: 0.56) // Teal for next trip
        }
        return Color(red: 0.28, green: 0.23, blue: 0.52) // Purple for other trips
    }
    
    private var badgeColor: Color {
        if leg.isFromCurrentLocation {
            return Color(red: 0.89, green: 0.98, blue: 0.96) // Light teal
        }
        return Color(red: 0.94, green: 0.89, blue: 0.99) // Light purple
    }
    
    private var cardBackgroundColor: Color {
        if leg.isFromCurrentLocation {
            return Color.white
        }
        return Color.white.opacity(0.92)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        TripsView(
            viewModel: TripsViewModel(
                initialItinerary: TripLeg.previewData,
                initialCurrentLocation: CurrentLocation.previewData
            ),
            parksViewModel: ParksViewModel(parks: Park.sampleData, parksService: ParksService())
        )
    }
}
#endif
