import SwiftUI

@MainActor
struct ParksView: View {
    @StateObject private var viewModel: ParksViewModel

    private let backgroundGradient = LinearGradient(colors: [
        Color(red: 0.95, green: 0.96, blue: 0.99),
        Color(red: 0.99, green: 0.95, blue: 0.89)
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    init(viewModel: ParksViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: ParksViewModel())
    }

    var body: some View {
        List {
            filtersSection
            resultsSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(backgroundGradient.ignoresSafeArea())
        .navigationTitle("Parks")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text("Search by name or city"))
        .refreshable {
            print("🔄 User triggered refresh")
            await viewModel.loadParks(forceReload: true)
        }
        .task {
            print("📱 ParksView appeared, loading parks")
            await viewModel.loadParks()
        }
    }

    private var filtersSection: some View {
        Section {
            VStack(spacing: 14) {
                // Row 1: Sort and Favorites
                HStack(spacing: 12) {
                    // Sort picker
                    Menu {
                        Picker("Sort by", selection: $viewModel.sortOption) {
                            ForEach(ParksViewModel.SortOption.allCases) { option in
                                Label(option.displayName, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.subheadline)
                            Text(viewModel.sortOption.displayName)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                    }
                    
                    Spacer()
                    
                    // Favorites toggle
                    Button(action: {
                        withAnimation(.easeInOut) {
                            viewModel.showFamilyFavoritesOnly.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.showFamilyFavoritesOnly ? "star.fill" : "star")
                                .font(.subheadline)
                            Text("4★+")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.showFamilyFavoritesOnly
                                ? Color(red: 0.96, green: 0.73, blue: 0.26)
                                : Color.white.opacity(0.9),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .foregroundStyle(
                            viewModel.showFamilyFavoritesOnly
                                ? Color.white
                                : Color(red: 0.28, green: 0.23, blue: 0.52)
                        )
                    }
                }
                
                // Row 2: State picker
                if !viewModel.availableStates.isEmpty {
                    Menu {
                        Picker("State", selection: $viewModel.selectedState) {
                            Text("All States").tag(String?.none)
                            ForEach(viewModel.availableStates, id: \.self) { state in
                                Text(state).tag(String?.some(state))
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.subheadline)
                            Text(viewModel.selectedState ?? "All States")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                    }
                }
                
                // Row 3: Membership scroll
                VStack(alignment: .leading, spacing: 8) {
                    Text("Membership")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(viewModel.membershipFilters) { filter in
                                Button(action: {
                                    withAnimation(.easeInOut) {
                                        viewModel.selectedFilter = filter
                                    }
                                }) {
                                    Text(filter.displayName)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                                .fill(filter.id == viewModel.selectedFilter.id
                                                    ? Color(red: 0.36, green: 0.31, blue: 0.55)
                                                    : Color.white.opacity(0.85))
                                        )
                                        .foregroundStyle(filter.id == viewModel.selectedFilter.id
                                            ? Color.white
                                            : Color(red: 0.28, green: 0.23, blue: 0.52))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private var resultsSection: some View {
        Section {
            if viewModel.isLoading && !viewModel.hasLoadedParks {
                loadingView
            } else if let error = viewModel.loadError, !viewModel.hasLoadedParks {
                errorView(error)
            } else if viewModel.filteredParks.isEmpty {
                emptyStateView
            } else {
                parksListContent
            }
        } header: {
            resultsHeader
        }
        .listRowBackground(Color.clear)
    }
    
    private var resultsHeader: some View {
        HStack {
            Text("Results")
                .font(.headline)
                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
            
            Spacer()
            
            if !viewModel.filteredParks.isEmpty {
                Text("\(viewModel.filteredParks.count) parks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .textCase(nil)
    }
    
    private var parksListContent: some View {
        Group {
            if let error = viewModel.loadError {
                errorBanner(error)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            ForEach(viewModel.filteredParks) { park in
                NavigationLink {
                    ParkDetailView(viewModel: viewModel.makeDetailViewModel(for: park))
                } label: {
                    ParkRowView(park: park)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52).opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No parks match")
                    .font(.headline)
                
                Text("Try adjusting your filters or search terms")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - Subviews

private extension ParksView {
    var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.2)
            
            Text("Loading parks…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.orange)
            
            VStack(spacing: 8) {
                Text("Couldn't load parks")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Button(action: {
                Task {
                    print("🔄 Retry button tapped")
                    await viewModel.loadParks(forceReload: true)
                }
            }) {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.36, green: 0.31, blue: 0.55), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    func errorBanner(_ error: Error) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't refresh")
                    .font(.footnote)
                    .fontWeight(.semibold)
                
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Park Row View

private struct ParkRowView: View {
    let park: Park

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with name and location
            VStack(alignment: .leading, spacing: 4) {
                Text(park.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                
                Text(park.formattedLocation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            // Ratings row
            HStack(spacing: 16) {
                ratingBadge(
                    title: "Family",
                    icon: "star.fill",
                    value: park.familyRating,
                    count: park.familyReviewCount,
                    accent: Color(red: 0.36, green: 0.31, blue: 0.55)
                )
                
                if let communityRating = park.communityRating {
                    ratingBadge(
                        title: "Community",
                        icon: "person.3.fill",
                        value: communityRating,
                        count: park.communityReviewCount,
                        accent: Color(red: 0.42, green: 0.37, blue: 0.67)
                    )
                }
                
                Spacer()
            }

            // Memberships
            if !park.memberships.isEmpty {
                membershipTags
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.95))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        )
    }
    
    private func ratingBadge(title: String, icon: String, value: Double, count: Int, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(String(format: "%.1f", value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.12), in: Capsule())
            .foregroundStyle(accent)
            
            if count > 0 {
                Text("\(count) reviews")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var membershipTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(park.memberships, id: \.id) { membership in
                    Text(membership.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(membership.badgeColor.opacity(0.15), in: Capsule())
                        .foregroundStyle(membership.badgeColor)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    NavigationStack {
        ParksView(viewModel: ParksViewModel(parks: Park.sampleData))
    }
}

#Preview("Loading") {
    NavigationStack {
        ParksView(viewModel: ParksViewModel(parks: []))
    }
}
