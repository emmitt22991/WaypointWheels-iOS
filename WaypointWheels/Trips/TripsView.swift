import SwiftUI
import MapKit

struct TripsView: View {
    @State private var itinerary: [TripLeg] = TripLeg.sample
    @State private var showDeleteConfirmation: TripLeg?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    TripPlanView(legs: itinerary)
                } label: {
                    tripPlanButton
                }
                .listRowBackground(Color.clear)
            }
            .textCase(nil)

            if itinerary.isEmpty {
                emptyState
                    .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Itinerary")) {
                    ForEach(Array(itinerary.enumerated()), id: \.element.id) { index, leg in
                        TimelineRow(
                            leg: leg,
                            isFirst: index == 0,
                            isLast: index == itinerary.count - 1
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
                    itinerary.removeAll { $0.id == leg.id }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { leg in
            Text("\(leg.start.name) to \(leg.end.name) will be removed from your route.")
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
                    Text("\(leg.distanceInMiles) miles · \(leg.estimatedDriveTime)")
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
        TripsView()
    }
}
