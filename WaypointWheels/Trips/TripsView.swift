import SwiftUI

struct TripsView: View {
    @StateObject private var viewModel: TripsViewModel
    @State private var showDeleteConfirmation: TripLeg?

    @MainActor
    init(viewModel: TripsViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? TripsViewModel())
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TripPlanView(legs: viewModel.itinerary)
                } label: {
                    tripPlanButton
                }
                .listRowBackground(Color.clear)
            }
            .textCase(nil)

            if viewModel.isLoading {
                loadingState
            } else if let errorMessage = viewModel.errorMessage {
                errorState(message: errorMessage)
            } else if viewModel.itinerary.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Itinerary")) {
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

            if let payload = viewModel.debugPayloadCache,
               !viewModel.isLoading,
               viewModel.errorMessage == nil {
                Section {
                    debugPayloadView(payload: payload, includeDivider: false)
                        .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
                .textCase(nil)
                .listRowBackground(Color.clear)
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

            if let payload = viewModel.debugPayloadCache {
                debugPayloadView(payload: payload)
            }
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

private extension TripsView {
    func debugPayloadView(payload: String, includeDivider: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if includeDivider {
                Divider()
                    .padding(.vertical, 4)
            }

            Text("Response Payload")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(payload)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 180)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimelineRow: View {
    let leg: TripLeg
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(red: 0.28, green: 0.23, blue: 0.52))
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

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(leg.dayLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(red: 0.94, green: 0.89, blue: 0.99))
                        .clipShape(Capsule())
                    Text(leg.dateRangeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(leg.start.name) → \(leg.end.name)")
                        .font(.headline)
                    Text("\(String(format: "%.1f", leg.distanceInMiles)) miles · \(leg.estimatedDriveTime)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

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

                if let notes = leg.notes {
                    Divider()
                        .padding(.vertical, 4)
                    Text(notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        TripsView(viewModel: TripsViewModel(initialItinerary: TripLeg.previewData))
    }
}
