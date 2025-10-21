import SwiftUI

struct ParksView: View {
    @StateObject private var viewModel = ParksViewModel(parks: [], parksService: ParksService())
    @State private var showFilters = false
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            if viewModel.isLoading && !viewModel.hasLoadedParks {
                loadingView
            } else if let error = viewModel.loadError, !viewModel.hasLoadedParks {
                errorView(error)
            } else if viewModel.filteredParks.isEmpty {
                emptyStateView
            } else {
                parksList
            }
        }
        .navigationTitle("Parks (\(viewModel.filteredParks.count))")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters.toggle()
                } label: {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Sort by", selection: $viewModel.sortOption) {
                        ForEach(ParksViewModel.SortOption.allCases) { option in
                            Label(option.displayName, systemImage: option.icon)
                                .tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search parks, cities, or states")
        .sheet(isPresented: $showFilters) {
            filtersSheet
        }
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
    
    private var parksList: some View {
        List {
            ForEach(viewModel.filteredParks) { park in
                NavigationLink {
                    let parksService = ParksService()
                    let detailViewModel = ParkDetailViewModel(
                        parkID: park.id,
                        initialSummary: park,
                        service: parksService,
                        onParkUpdated: { _ in }
                    )
                    ParkDetailView(viewModel: detailViewModel)
                } label: {
                    ParkRow(park: park)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }
    
    private var filtersSheet: some View {
        NavigationStack {
            Form {
                Section("Membership") {
                    Picker("Membership", selection: $viewModel.selectedFilter) {
                        ForEach(viewModel.membershipFilters) { filter in
                            Text(filter.displayName).tag(filter)
                }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                
                Section("State") {
                    Picker("State", selection: $viewModel.selectedState) {
                        Text("All States").tag(nil as String?)
                        ForEach(viewModel.availableStates, id: \.self) { state in
                            Text(state).tag(state as String?)
                        }
                    }
                }
                
                Section("Rating") {
                    Toggle("Family Favorites (4★+)", isOn: $viewModel.showFamilyFavoritesOnly)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        viewModel.selectedFilter = .all
                        viewModel.selectedState = nil
                        viewModel.showFamilyFavoritesOnly = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilters = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        ParksView()
    }
}
