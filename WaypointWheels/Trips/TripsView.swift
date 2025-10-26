import SwiftUI

@MainActor
struct TripsView: View {
    @StateObject private var viewModel: TripsViewModel
    @State private var showDeleteConfirmation: TripLeg?

    @MainActor
    init(viewModel: TripsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? TripsViewModel())
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
                            isLast: index == viewModel.itinerary.count - 1
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
        }
        .refreshable {
            await viewModel.loadItinerary(forceReload: true)
        }
    }

    private var tripPlanButton: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(red: 0.87, green: 0.90, blue: 0.97))
                    .frame(width: 64, height: 64)
                Image(systemName: "map.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Trip Plan")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("Open the map to set your starting point, waypoints, and final stop.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView("Loading itinerary…")
                .padding(.vertical, 24)
            Spacer()
        }
        .listRowBackground(Color.clear)
    }

    private func errorState(message: String) -> some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.orange)
            Text("We couldn't load your trip")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task {
                    await viewModel.loadItinerary(forceReload: true)
                }
            } label: {
                Text("Try Again")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
    }

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
            Text("No trip legs yet")
                .font(.headline)
            Text("Add your first route leg from the Trip Plan map to build an itinerary.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Current Location Card

private struct CurrentLocationCard: View {
    let location: CurrentLocation
    @State private var showingParkDetail = false
    
    var body: some View {
        Button {
            showingParkDetail = true
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingParkDetail) {
            NavigationStack {
                ParkDetailDestination(location: location)
            }
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
        if parts.count > 1 {
            return parts[1].trimmingCharacters(in: .whitespaces)
        }
        return ""
    }
}

// MARK: - Timeline Row

private struct TimelineRow: View {
    let leg: TripLeg
    let isFirst: Bool
    let isLast: Bool

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

                // Route
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(leg.start.name) → \(leg.end.name)")
                        .font(.headline)
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

#Preview {
    NavigationStack {
        TripsView(
            viewModel: TripsViewModel(
                initialItinerary: TripLeg.previewData,
                initialCurrentLocation: CurrentLocation.previewData
            )
        )
    }
}
