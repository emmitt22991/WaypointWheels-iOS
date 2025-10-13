import SwiftUI
import MapKit

struct TripPlanView: View {
    let legs: [TripLeg]

    private let stops: [TripLocation]
    @State private var cameraPosition: MapCameraPosition
    @State private var selectedLocation: TripLocation?

    init(legs: [TripLeg]) {
        self.legs = legs
        self.stops = TripPlanView.uniqueStops(from: legs)
        let defaultRegion = TripPlanView.makeRegion(for: stops)
        _cameraPosition = State(initialValue: .region(defaultRegion))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition, interactionModes: .all) {
                ForEach(stops) { location in
                    Annotation(label(for: location), coordinate: location.coordinate) {
                        VStack(spacing: 4) {
                            Text(label(for: location))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(locationBadgeColor(for: location))
                                .foregroundStyle(Color.white)
                                .clipShape(Capsule())
                            Image(systemName: iconName(for: location))
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                                .padding(6)
                                .background(Color.white, in: Circle())
                                .shadow(radius: 4)
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        selectedLocation = location
                                    }
                                }
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            .frame(minHeight: 300)

            Divider()
                .padding(.vertical, 12)

            detailsSection
                .padding(.horizontal)
                .padding(.bottom)
        }
        .navigationTitle("Trip Plan")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(item: $selectedLocation) { location in
            NavigationStack {
                LocationDetailView(location: location, legs: legs)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                selectedLocation = nil
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stops Overview")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(legs) { leg in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("\(leg.start.name)")
                            .font(.headline)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(leg.end.name)
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.1f mi", leg.distanceInMiles))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(leg.dateRangeDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Drive time · \(leg.estimatedDriveTime)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 4)
            }
        }
    }

    private func label(for location: TripLocation) -> String {
        guard let firstLeg = legs.first, let lastLeg = legs.last else { return location.name }

        if location.id == firstLeg.start.id {
            return "Start"
        } else if location.id == lastLeg.end.id {
            return "Finish"
        } else {
            return location.name
        }
    }

    private func iconName(for location: TripLocation) -> String {
        guard let firstLeg = legs.first, let lastLeg = legs.last else { return "mappin" }
        if location.id == firstLeg.start.id {
            return "flag.fill"
        } else if location.id == lastLeg.end.id {
            return "checkered.flag"
        } else {
            return "mappin.circle.fill"
        }
    }

    private func locationBadgeColor(for location: TripLocation) -> Color {
        guard let firstLeg = legs.first, let lastLeg = legs.last else { return Color(red: 0.32, green: 0.29, blue: 0.55) }
        if location.id == firstLeg.start.id {
            return Color(red: 0.27, green: 0.64, blue: 0.56)
        } else if location.id == lastLeg.end.id {
            return Color(red: 0.91, green: 0.50, blue: 0.30)
        } else {
            return Color(red: 0.32, green: 0.29, blue: 0.55)
        }
    }

    private static func uniqueStops(from legs: [TripLeg]) -> [TripLocation] {
        var seen: Set<TripLocation> = []
        var ordered: [TripLocation] = []

        for leg in legs {
            if !seen.contains(leg.start) {
                seen.insert(leg.start)
                ordered.append(leg.start)
            }
            if !seen.contains(leg.end) {
                seen.insert(leg.end)
                ordered.append(leg.end)
            }
        }

        return ordered
    }

    private static func makeRegion(for stops: [TripLocation]) -> MKCoordinateRegion {
        guard let first = stops.first else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.0902, longitude: -95.7129),
                span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
            )
        }

        var minLat = first.coordinate.latitude
        var maxLat = first.coordinate.latitude
        var minLon = first.coordinate.longitude
        var maxLon = first.coordinate.longitude

        for stop in stops.dropFirst() {
            minLat = min(minLat, stop.coordinate.latitude)
            maxLat = max(maxLat, stop.coordinate.latitude)
            minLon = min(minLon, stop.coordinate.longitude)
            maxLon = max(maxLon, stop.coordinate.longitude)
        }

        let latitudeDelta = max((maxLat - minLat) * 1.5, 1.5)
        let longitudeDelta = max((maxLon - minLon) * 1.5, 1.5)
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta))
    }
}

private struct LocationDetailView: View {
    let location: TripLocation
    let legs: [TripLeg]

    private var relatedLegs: [TripLeg] {
        legs.filter { $0.start == location || $0.end == location }
    }

    var body: some View {
        List {
            Section(header: Text(location.name)) {
                Text(location.description)
                    .font(.body)
                Text("Lat: \(location.coordinate.latitude, specifier: "%.4f"), Lng: \(location.coordinate.longitude, specifier: "%.4f")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Legs")) {
                ForEach(relatedLegs) { leg in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(leg.start.name) → \(leg.end.name)")
                            .font(.subheadline)
                        Text(leg.dateRangeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        TripPlanView(legs: TripLeg.previewData)
    }
}
