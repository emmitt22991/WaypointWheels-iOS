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
        .refreshable { await viewModel.loadParks(forceReload: true) }
        .task { await viewModel.loadParks() }
    }

    private var filtersSection: some View {
        Section("Filters") {
            sortPicker
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

    private var sortPicker: some View {
        HStack {
            Label("Sort by", systemImage: "arrow.up.arrow.down")
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
            Spacer()
            Picker("Sort by", selection: $viewModel.sortOption) {
                ForEach(ParksViewModel.SortOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.menu)
        }
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
                tableHeader
                ForEach(viewModel.filteredParks) { park in
                    NavigationLink {
                        ParkDetailView(viewModel: viewModel.makeDetailViewModel(for: park))
                    } label: {
                        ParkRowView(park: park)
                            .listRowSeparator(.hidden)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}

private extension ParksView {
    private enum ParksViewLayout {
        static let ratingColumnWidth: CGFloat = 104
    }

    var tableHeader: some View {
        HStack {
            Text("Park")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Family")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: ParksViewLayout.ratingColumnWidth, alignment: .trailing)

            Text("Community")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: ParksViewLayout.ratingColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

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
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(park.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                    Text(park.formattedLocation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                ratingColumn(title: "Family", icon: "star.fill", value: park.familyRating, accent: Color(red: 0.36, green: 0.31, blue: 0.55))

                ratingColumn(title: "Community", icon: "person.3.fill", value: park.communityRating, accent: Color(red: 0.42, green: 0.37, blue: 0.67))
            }

            memberships

            if let summary = reviewSummary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.94))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }

    private func ratingColumn(title: String, icon: String, value: Double?, accent: Color) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 6) {
                Image(systemName: icon)
                if let value {
                    Text(String(format: "%.1f", value))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } else {
                    Text("—")
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.12), in: Capsule())
            .foregroundStyle(accent)
        }
        .frame(width: ParksViewLayout.ratingColumnWidth, alignment: .trailing)
    }

    private var memberships: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
            }
            .padding(.vertical, 2)
        }
    }

    private var reviewSummary: String? {
        let family = park.familyReviewCount
        let community = park.communityReviewCount

        switch (family, community) {
        case (0, 0):
            return nil
        case (_, 0):
            return "\(family) family comments"
        case (0, _):
            return "\(community) community comments"
        default:
            return "\(family) family · \(community) community comments"
        }
    }
}

#Preview {
    ParksView(viewModel: ParksViewModel(parks: Park.sampleData))
}
