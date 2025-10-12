import SwiftUI

struct ParksView: View {
    @StateObject private var viewModel: ParksViewModel

    init(viewModel: ParksViewModel = ParksViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    filters
                    parkList
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                LinearGradient(colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.99),
                    Color(red: 0.99, green: 0.95, blue: 0.89)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            )
            .navigationTitle("Parks")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationDestination(for: Park.self) { park in
            ParkDetailView(park: park)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find Your Next Stay")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .tracking(1.1)
            Text("Filter by memberships or surface our family's four-star favorites.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 16) {
            membershipPicker
            Toggle(isOn: $viewModel.showFamilyFavoritesOnly.animation(.easeInOut)) {
                Label("Show family favorites (4★+)", systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
            }
            .toggleStyle(SwitchToggleStyle(tint: Color(red: 0.36, green: 0.31, blue: 0.55)))
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .padding(.horizontal, 4)
        }
    }

    private var parkList: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.filteredParks.isEmpty {
                ContentUnavailableView(
                    "No parks match right now",
                    systemImage: "leaf",
                    description: Text("Try adjusting membership filters or disable family favorites.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(spacing: 18, pinnedViews: []) {
                    ForEach(viewModel.filteredParks) { park in
                        NavigationLink(value: park) {
                            ParkRowView(park: park)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct ParkRowView: View {
    let park: Park

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(park.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                    Text(park.formattedLocation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ratingBadge
            }

            memberships

            Text(park.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 12) {
                ForEach(park.amenities.prefix(3)) { amenity in
                    Label(amenity.name, systemImage: amenity.systemImage)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.32, green: 0.29, blue: 0.55))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.9), in: Capsule())
                }
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
        }
    }
}

private struct ParkDetailView: View {
    let park: Park

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                descriptionSection
                amenitiesSection
                notesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(
            LinearGradient(colors: [
                Color(red: 0.97, green: 0.94, blue: 0.86),
                Color(red: 0.92, green: 0.97, blue: 0.98)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
        )
        .navigationTitle(park.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(park.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text(park.formattedLocation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ratingBadge
            }
            memberships
        }
    }

    private var ratingBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
            Text(String(format: "%.1f / 5", park.rating))
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.98, green: 0.88, blue: 0.63), in: Capsule())
        .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
    }

    private var memberships: some View {
        HStack(spacing: 10) {
            ForEach(park.memberships, id: \.self) { membership in
                Text(membership.rawValue)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(membership.badgeColor.opacity(0.18), in: Capsule())
                    .foregroundStyle(membership.badgeColor)
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Park Overview")
                .font(.title3)
                .fontWeight(.semibold)
            Text(park.description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var amenitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Amenities")
                .font(.title3)
                .fontWeight(.semibold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)]) {
                ForEach(park.amenities) { amenity in
                    VStack(spacing: 8) {
                        Image(systemName: amenity.systemImage)
                            .font(.title2)
                            .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                        Text(amenity.name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Notes")
                .font(.title3)
                .fontWeight(.semibold)
            VStack(alignment: .leading, spacing: 10) {
                ForEach(park.featuredNotes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color(red: 0.36, green: 0.31, blue: 0.55))
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    ParksView(viewModel: ParksViewModel())
}
