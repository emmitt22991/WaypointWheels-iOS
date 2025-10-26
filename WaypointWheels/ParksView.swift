import SwiftUI

struct ParksView: View {
    @StateObject private var viewModel = ParksViewModel(parks: [], parksService: ParksService())
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters section - prominent at top
            filtersSection
            
            // Content
            ZStack {
                backgroundGradient
                
                if viewModel.isLoading && !viewModel.hasLoadedParks {
                    loadingView
                } else if let error = viewModel.loadError, !viewModel.hasLoadedParks {
                    errorView(error)
                } else if viewModel.filteredParks.isEmpty {
                    emptyStateView
                } else {
                    parksTable
                }
            }
        }
        .navigationTitle("Parks")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadParks()
        }
        .refreshable {
            await viewModel.loadParks(forceReload: true)
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(colors: [
            Color(red: 0.97, green: 0.94, blue: 0.86),
            Color(red: 0.92, green: 0.97, blue: 0.98)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }
    
    // MARK: - Filters Section
    private var filtersSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search parks, cities, or states", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
            
            // Filter chips row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Sort picker
                    Menu {
                        Picker("Sort by", selection: $viewModel.sortOption) {
                            ForEach(ParksViewModel.SortOption.allCases) { option in
                                Label(option.displayName, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(viewModel.sortOption.displayName)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.15), in: Capsule())
                        .foregroundColor(.blue)
                    }
                    
                    // Membership filter
                    Menu {
                        Picker("Membership", selection: $viewModel.selectedFilter) {
                            ForEach(viewModel.membershipFilters) { filter in
                                Text(filter.displayName).tag(filter)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "building.2")
                            Text(viewModel.selectedFilter.displayName)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedFilter.displayName != "All Memberships"
                                ? Color.orange.opacity(0.15)
                                : Color(.systemGray5),
                            in: Capsule()
                        )
                        .foregroundColor(
                            viewModel.selectedFilter.displayName != "All Memberships"
                                ? .orange
                                : .secondary
                        )
                    }
                    
                    // State filter
                    Menu {
                        Picker("State", selection: $viewModel.selectedState) {
                            Text("All States").tag(nil as String?)
                            ForEach(viewModel.availableStates, id: \.self) { state in
                                Text(state).tag(state as String?)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "map")
                            Text(viewModel.selectedState ?? "All States")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.selectedState != nil
                                ? Color.green.opacity(0.15)
                                : Color(.systemGray5),
                            in: Capsule()
                        )
                        .foregroundColor(
                            viewModel.selectedState != nil
                                ? .green
                                : .secondary
                        )
                    }
                    
                    // Family Favorites toggle
                    Button {
                        viewModel.showFamilyFavoritesOnly.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.showFamilyFavoritesOnly ? "star.fill" : "star")
                            Text("4â˜…+")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.showFamilyFavoritesOnly
                                ? Color.yellow.opacity(0.25)
                                : Color(.systemGray5),
                            in: Capsule()
                        )
                        .foregroundColor(
                            viewModel.showFamilyFavoritesOnly
                                ? Color(red: 0.36, green: 0.31, blue: 0.55)
                                : .secondary
                        )
                    }
                    
                    // Reset filters button
                    if viewModel.selectedFilter.displayName != "All Memberships" ||
                       viewModel.selectedState != nil ||
                       viewModel.showFamilyFavoritesOnly {
                        Button {
                            viewModel.selectedFilter = .all
                            viewModel.selectedState = nil
                            viewModel.showFamilyFavoritesOnly = false
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Results count
            Text("\(viewModel.filteredParks.count) parks")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 2)
    }
    
    // MARK: - Data Table
    private var parksTable: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Table header
                tableHeader
                
                // Table rows
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredParks) { park in
                        NavigationLink {
                            ParkDetailView(
                                parkID: park.id,
                                initialSummary: park,
                                service: ParksService(),
                                onParkUpdated: { _ in }
                            )
                        } label: {
                            ParkTableRow(park: park)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(16)
        }
    }
    
    private var tableHeader: some View {
        HStack(spacing: 12) {
            // Park name column
            Text("Park")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minWidth: 150)
            
            // Location column
            Text("Location")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            // Family rating column
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.caption2)
                Text("Family")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.secondary)
            .frame(width: 60)
            
            // Community rating column
            HStack(spacing: 2) {
                Image(systemName: "person.3.fill")
                    .font(.caption2)
                Text("All")
            }
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.secondary)
            .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Empty/Loading/Error States
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading parks...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Unable to load parks")
                .font(.title2)
                .fontWeight(.bold)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                Task {
                    await viewModel.loadParks(forceReload: true)
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No parks found")
                .font(.title2)
                .fontWeight(.bold)
            Text("Try adjusting your filters or search")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Park Table Row
struct ParkTableRow: View {
    let park: Park
    
    var body: some View {
        HStack(spacing: 12) {
            // Park name and memberships column
            VStack(alignment: .leading, spacing: 6) {
                Text(park.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if !park.memberships.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(park.memberships.prefix(2), id: \.id) { membership in
                            Text(membership.name)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(membership.badgeColor.opacity(0.15), in: Capsule())
                                .foregroundStyle(membership.badgeColor)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minWidth: 150)
            
            // Location column
            VStack(alignment: .leading, spacing: 2) {
                Text(park.city)
                    .font(.caption)
                    .foregroundColor(.primary)
                Text(park.state)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .leading)
            
            // Family rating column
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                Text(String(format: "%.1f", park.familyRating))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                    .monospacedDigit()
            }
            .frame(width: 60)
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(Color(red: 0.98, green: 0.88, blue: 0.63).opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            
            // Community rating column
            if let communityRating = park.communityRating {
                HStack(spacing: 4) {
                    Image(systemName: "person.3.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.42, green: 0.37, blue: 0.67))
                    Text(String(format: "%.1f", communityRating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.42, green: 0.37, blue: 0.67))
                        .monospacedDigit()
                }
                .frame(width: 60)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Color(red: 0.94, green: 0.90, blue: 0.99).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            } else {
                Text("â€”")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(width: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationStack {
        ParksView()
    }
}
