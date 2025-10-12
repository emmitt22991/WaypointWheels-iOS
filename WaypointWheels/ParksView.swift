import SwiftUI

@MainActor
struct ParksView: View {
    @StateObject private var viewModel: ParksViewModel

    init(viewModel: ParksViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    init() {
        self.init(viewModel: ParksViewModel())
    }

    var body: some View {
        NavigationStack {
            List {
                filtersSection
                resultsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(backgroundGradient)
            .navigationTitle("Parks")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: Text("Search by name or city"))
            .refreshable { await viewModel.loadParks(forceReload: true) }
        }
        .navigationDestination(for: Park.self) { park in
            ParkDetailView(viewModel: viewModel.makeDetailViewModel(for: park))
        }
        .task { await viewModel.loadParks() }
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [
            Color(red: 0.95, green: 0.96, blue: 0.99),
            Color(red: 0.99, green: 0.95, blue: 0.89)
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        .ignoresSafeArea()
    }

    private var filtersSection: some View {
        Section("Filters") {
            membershipPicker
            Toggle(isOn: $viewModel.showFamilyFavoritesOnly.animation(.easeInOut)) {
                Label("Show family favorites (4★+)", systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.36, green: 0.31, blue: 0.55)))
            statePicker
        }
        .listRowBackground(Color.clear)
    }

    private var membershipPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.membershipFilters) { filter in
                    Button(action: {
                        withAnimation(.easeInOut) {
                            viewModel.selectedFilter = filter
                        }
                    }) {
                        Text(filter.displayName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(filter.id == viewModel.selectedFilter.id ? Color(red: 0.36, green: 0.31, blue: 0.55) : Color.white.opacity(0.85))
                            )
                            .foregroundStyle(filter.id == viewModel.selectedFilter.id ? Color.white : Color(red: 0.28, green: 0.23, blue: 0.52))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
    }

    private var statePicker: some View {
        Picker("State", selection: $viewModel.selectedState) {
            Text("All States").tag(String?.none)
            ForEach(viewModel.availableStates, id: \.self) { state in
                Text(state).tag(String?.some(state))
            }
        }
        .pickerStyle(.menu)
    }

    private var resultsSection: some View {
        Section("Results") {
            if viewModel.isLoading && !viewModel.hasLoadedParks {
                loadingView
            } else if let error = viewModel.loadError, !viewModel.hasLoadedParks {
                errorView(error)
            } else if viewModel.filteredParks.isEmpty {
                ContentUnavailableView(
                    "No parks match right now",
                    systemImage: "leaf",
                    description: Text("Try adjusting your filters or search terms.")
                )
                .frame(maxWidth: .infinity)
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            } else {
                if let error = viewModel.loadError {
                    errorBanner(error)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                }
                ForEach(viewModel.filteredParks) { park in
                    NavigationLink(value: park) {
                        ParkRowView(park: park)
                            .listRowSeparator(.hidden)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}

private extension ParksView {
    var loadingView: some View {
        HStack {
            Spacer()
            ProgressView("Loading parks…")
                .progressViewStyle(.circular)
            Spacer()
        }
        .padding(.vertical, 16)
    }

    func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(Color.orange)
            Text("We couldn’t load parks right now.")
                .font(.headline)
            Text(error.localizedDescription)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: { Task { await viewModel.loadParks(forceReload: true) } }) {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    func errorBanner(_ error: Error) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
            Text("Couldn’t refresh parks: \(error.localizedDescription)")
                .font(.footnote)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Color.orange)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ParkRowView: View {
    let park: Park

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(park.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                    Text(park.formattedLocation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ratingBadge
            }

            memberships
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }

    private var ratingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
            Text(String(format: "%.1f", park.rating))
                .fontWeight(.semibold)
        }
        .font(.footnote)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.98, green: 0.88, blue: 0.63), in: Capsule())
        .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
    }

    private var memberships: some View {
        HStack(spacing: 8) {
            ForEach(park.memberships, id: \.self) { membership in
                Text(membership.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(membership.badgeColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(membership.badgeColor)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    ParksView(viewModel: ParksViewModel(parks: Park.sampleData))
}
