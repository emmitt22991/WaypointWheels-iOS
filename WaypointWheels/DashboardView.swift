import SwiftUI

@MainActor
struct DashboardView: View {
    let userName: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var checklistsViewModel = ChecklistsViewModel()
    @StateObject private var tripsViewModel = TripsViewModel()
    
    // Weather state - stores fetched weather data
    @State private var weatherTemperature: Int? = nil
    @State private var weatherHeadline: String? = nil
    @State private var weatherNarrative: String? = nil
    @State private var isLoadingWeather: Bool = false
    @State private var weatherError: String? = nil

    private let accentGradient = LinearGradient(colors: [
        Color(red: 0.98, green: 0.88, blue: 0.63),
        Color(red: 1.0, green: 0.95, blue: 0.82)
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    private let heroAccentGradient = LinearGradient(colors: [
        Color(red: 0.42, green: 0.37, blue: 0.67),
        Color(red: 0.25, green: 0.44, blue: 0.66)
    ], startPoint: .leading, endPoint: .trailing)

    private let heroBackgroundGradient = LinearGradient(colors: [
        Color(red: 0.99, green: 0.96, blue: 0.90),
        Color(red: 0.92, green: 0.96, blue: 0.98)
    ], startPoint: .topLeading, endPoint: .bottomTrailing)

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact || horizontalSizeClass == nil
    }

    private var heroTileColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompactWidth ? 220 : 260), spacing: 16)]
    }

    private var contentColumns: [GridItem] {
        [GridItem(.adaptive(minimum: isCompactWidth ? 260 : 300), spacing: 16)]
    }

    private var nextLeg: TripLeg? {
        tripsViewModel.itinerary.first
    }

    private var nextStopSubtitle: String {
        if let leg = nextLeg {
            return leg.end.name
        }

        if tripsViewModel.isLoading {
            return "Loading itinerary…"
        }

        if tripsViewModel.errorMessage != nil {
            return "Trip unavailable"
        }

        return "Plan your first route"
    }
    
    // MARK: - Computed Properties for Real Trip Data & Weather
    
    /// Returns the current location from trip data in "City, State" format
    private var currentLocationTitle: String {
        // Log what we're computing
        print("📍 DashboardView: Computing currentLocationTitle")
        
        if let leg = nextLeg {
            let location = leg.start.description // This is "City, State" format
            print("📍 Current location from trip: \(location)")
            return location
        }
        
        if tripsViewModel.isLoading {
            return "Loading location..."
        }
        
        return "No location set"
    }
    
    /// Returns detail about current location
    private var currentLocationDetail: String {
        if let leg = nextLeg {
            return "The crew is at \(leg.start.name)"
        }
        return "Set up your first trip to track your location"
    }
    
    /// Returns the next travel day formatted date
    private var nextTravelDayValue: String {
        print("📅 DashboardView: Computing nextTravelDayValue")
        
        guard let leg = nextLeg else {
            return "No travel planned"
        }
        
        return leg.dateRangeDescription
    }
    
    /// Returns detail about next travel day
    private var nextTravelDayDetail: String {
        guard let leg = nextLeg else {
            return "Plan your first route to see travel days"
        }
        
        return "Wheels up soon! You're bound for \(leg.end.name)."
    }
    
    /// Returns the weather display value
    private var todayVibeValue: String {
        print("🌤️ DashboardView: todayVibeValue - temp: \(String(describing: weatherTemperature)), headline: \(String(describing: weatherHeadline))")
        
        if isLoadingWeather {
            return "Loading weather..."
        }
        
        if weatherError != nil {
            return "Weather unavailable"
        }
        
        if let temp = weatherTemperature, let headline = weatherHeadline {
            return "\(temp)° & \(headline)"
        }
        
        return "Weather updates coming soon"
    }
    
    /// Returns the weather detail narrative
    private var todayVibeDetail: String {
        if weatherError != nil {
            return weatherError ?? "Weather unavailable"
        }
        
        if let narrative = weatherNarrative {
            return narrative
        }
        
        let location = currentLocationTitle
        if location == "Loading location..." || location == "No location set" {
            return "Set up your trip to see local weather conditions"
        }
        
        return "Weather updates coming soon for \(location)"
    }
    
    // MARK: - Checklist Helpers
    
    /// Returns true if there are incomplete tasks in today's daily checklists
    private var hasTasksToday: Bool {
        let incompleteTasks = checklistsViewModel.dailyChecklists
            .flatMap { $0.checklist.items }
            .filter { !$0.isComplete }
        
        print("📋 DashboardView: Checking hasTasksToday")
        print("📋 Daily checklists count: \(checklistsViewModel.dailyChecklists.count)")
        print("📋 Incomplete tasks count: \(incompleteTasks.count)")
        
        return !incompleteTasks.isEmpty
    }
    
    /// Returns the count of incomplete tasks today
    private var tasksTodayCount: Int {
        checklistsViewModel.dailyChecklists
            .flatMap { $0.checklist.items }
            .filter { !$0.isComplete }
            .count
    }
    
    // MARK: - Weather Fetching
    
    /// Fetches weather for the current trip location using city/state
    private func fetchWeather() async {
        print("🌤️ ========================================")
        print("🌤️ fetchWeather() called")
        print("🌤️ ========================================")
        
        // Get the city/state location (NOT park name)
        let location = currentLocationTitle
        print("🌤️ Current location title: '\(location)'")
        
        // Don't fetch if we don't have a valid location yet
        guard location != "Loading location..." && location != "No location set" else {
            print("🌤️ ⚠️ No valid location available yet, skipping weather fetch")
            weatherError = "Set up your trip to see weather"
            return
        }
        
        // Set loading state
        await MainActor.run {
            print("🌤️ Setting isLoadingWeather = true")
            isLoadingWeather = true
            weatherError = nil
        }
        
        // Build the weather API request
        // Use path parameter instead of query string to avoid URL encoding issues
        // Format: weather.php/Saulsbury, TN
        let path = "weather.php/\(location)"
        print("🌤️ ==========================================")
        print("🌤️ API path: \(path)")
        print("🌤️ Location: \(location)")
        print("🌤️ ==========================================")
        
        do {
            // Create API client and make request
            let client = APIClient()
            print("🌤️ APIClient created, making request...")
            
            let response: Data = try await client.request(path: path, method: .get)
            print("🌤️ ✅ Response received, size: \(response.count) bytes")
            
            // Log raw response for debugging
            if let responseString = String(data: response, encoding: .utf8) {
                print("🌤️ Raw response: \(responseString)")
            }
            
            // Parse the JSON response
            let decoder = JSONDecoder()
            let weatherResponse = try decoder.decode(WeatherResponse.self, from: response)
            
            print("🌤️ ✅ JSON decoded successfully")
            print("🌤️ Status: \(weatherResponse.status)")
            print("🌤️ Temperature: \(String(describing: weatherResponse.temperatureRounded))")
            print("🌤️ Headline: \(String(describing: weatherResponse.headline))")
            
            // Check if weather was successfully fetched
            guard weatherResponse.status == "ok" else {
                print("🌤️ ⚠️ Weather status not 'ok': \(weatherResponse.status)")
                await MainActor.run {
                    isLoadingWeather = false
                    if let errorCode = weatherResponse.errorCode {
                        weatherError = "Weather unavailable (\(errorCode))"
                    } else {
                        weatherError = "Weather unavailable"
                    }
                }
                return
            }
            
            // Update UI with weather data
            await MainActor.run {
                print("🌤️ Updating UI with weather data...")
                weatherTemperature = weatherResponse.temperatureRounded
                weatherHeadline = weatherResponse.headline
                weatherNarrative = weatherResponse.narrative
                isLoadingWeather = false
                weatherError = nil
                print("🌤️ ✅ UI updated successfully!")
            }
            
        } catch {
            print("🌤️ ❌ ==========================================")
            print("🌤️ ❌ Error fetching weather")
            print("🌤️ ❌ Error: \(error)")
            print("🌤️ ❌ Error type: \(type(of: error))")
            print("🌤️ ❌ Error localized: \(error.localizedDescription)")
            
            // Try to get more details if it's an APIError
            if let apiError = error as? APIClient.APIError {
                print("🌤️ ❌ APIClient.APIError details: \(apiError)")
            }
            
            // Check if it's a decoding error
            if error is DecodingError {
                print("🌤️ ❌ This is a DecodingError")
            }
            
            print("🌤️ ❌ ==========================================")
            
            await MainActor.run {
                isLoadingWeather = false
                weatherError = "Unable to fetch weather"
            }
        }
        
        print("🌤️ ========================================")
        print("🌤️ fetchWeather() complete")
        print("🌤️ ========================================")
    }

    var body: some View {
        ZStack(alignment: .top) {
            heroBackgroundGradient
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        heroSection
                        travelHighlights
                        communityPulse
                        parksPreview
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 120)
                }
                .refreshable {
                    await tripsViewModel.loadItinerary(forceReload: true)
                    await checklistsViewModel.refresh()
                    await fetchWeather() // Refresh weather too
                }

                                bottomNavigation
                            }
                        }
                        .task {
                            print("⚡ DashboardView: .task block starting")
                            await tripsViewModel.loadItinerary()
                            await checklistsViewModel.refresh() // Load daily checklists
                            print("⚡ Trip itinerary loaded, now fetching weather")
                            await fetchWeather() // Fetch weather after trip data loads
                            print("⚡ DashboardView: .task block complete")
                        }
                        .navigationDestination(for: Park.self) { park in
                            ParkDetailView(
                                parkID: park.id,
                                initialSummary: park,
                                service: ParksService(),
                                onParkUpdated: { _ in }
                            )
                        }
                    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if #available(iOS 16.0, *) {
                ViewThatFits {
                    HStack(alignment: .center, spacing: 16) {
                        heroHeader
                        Spacer(minLength: 16)
                        heroProfile
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        heroHeader
                        heroProfile
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    heroHeader
                    heroProfile
                }
            }

            DashboardCard(title: "From the Caravan", subtitle: "Waypoint Wheels Dashboard", accent: accentGradient) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create plans, track your travels, the community, and what's coming up next.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: heroTileColumns, alignment: .leading, spacing: 16) {
                        // REAL current location from trip data
                        dashboardTile(
                            title: "Current Location",
                            value: currentLocationTitle,
                            detail: currentLocationDetail,
                            icon: "mappin.and.ellipse"
                        )
                        
                        // REAL next travel day from trip data
                        dashboardTile(
                            title: "Next Travel Day",
                            value: nextTravelDayValue,
                            detail: nextTravelDayDetail,
                            icon: "calendar"
                        )
                        
                        // REAL weather from weather API
                        dashboardTile(
                            title: "Today",
                            value: todayVibeValue,
                            detail: todayVibeDetail,
                            icon: isLoadingWeather ? "cloud" : (weatherError != nil ? "cloud.fill" : "sun.max.fill")
                        )
                    }
                }
            }
        }
    }

    private var travelHighlights: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Trip Toolkit")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink {
                    TripsView(viewModel: tripsViewModel)
                } label: {
                    Label("View Trip Calendar", systemImage: "calendar.badge.clock")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: contentColumns, alignment: .leading, spacing: 16) {
                DashboardCard(title: "Next Stop", subtitle: nextStopSubtitle, accent: accentGradient) {
                    nextStopCardContent
                }

                // Only show checklist card if there are tasks to do today
                if hasTasksToday {
                    DashboardCard(title: "Checklist", subtitle: "Tasks for Today", accent: accentGradient) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Simple alert-style message
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("You have \(tasksTodayCount) task\(tasksTodayCount == 1 ? "" : "s") to do today!")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("Don't forget to check your list")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            
                            // Prominent button to open checklists
                            NavigationLink {
                                ChecklistsView(viewModel: checklistsViewModel)
                            } label: {
                                HStack {
                                    Label("Open Your Checklist", systemImage: "list.bullet.rectangle")
                                        .font(.footnote)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color(red: 0.28, green: 0.23, blue: 0.52), in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var nextStopCardContent: some View {
        if tripsViewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Fetching your route…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let errorMessage = tripsViewModel.errorMessage {
            VStack(alignment: .leading, spacing: 12) {
                Label("We couldn't load your trip", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.orange)

                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await tripsViewModel.loadItinerary(forceReload: true) }
                } label: {
                    Text("Try Again")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.28, green: 0.23, blue: 0.52).opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)

                if let payload = tripsViewModel.debugPayloadCache {
                    debugPayloadCard(payload: payload)
                }
            }
        } else if let leg = nextLeg {
            VStack(alignment: .leading, spacing: 12) {
                tripRouteSummary(for: leg)
                timelineRow(title: "Travel Day", detail: leg.dateRangeDescription, symbol: "calendar")
                timelineRow(title: "Drive", detail: tripMetricsDescription(for: leg), symbol: "road.lanes")

                if let highlight = primaryHighlight(for: leg) {
                    Divider()
                        .padding(.vertical, 4)

                    Text(highlight)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label("No trip legs yet", systemImage: "calendar")
                    .font(.subheadline)

                Text("Add your first route leg from Trips to see upcoming stops here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                NavigationLink {
                    TripsView(viewModel: tripsViewModel)
                } label: {
                    Text("Plan a Trip")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.28, green: 0.23, blue: 0.52).opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tripRouteSummary(for leg: TripLeg) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                routeLocationPill(title: "Depart", value: leg.start.name, color: Color(red: 0.27, green: 0.64, blue: 0.56))

                Image(systemName: "arrow.forward")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))

                routeLocationPill(title: "Arrive", value: leg.end.name, color: Color(red: 0.91, green: 0.50, blue: 0.30))
            }

            Text(leg.dayLabel)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }

    private func routeLocationPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tripMetricsDescription(for leg: TripLeg) -> String {
        "\(formattedMiles(leg.distanceInMiles)) • \(leg.estimatedDriveTime)"
    }

    private func formattedMiles(_ miles: Double) -> String {
        let rounded = miles.rounded()
        if abs(rounded - miles) < 0.05 {
            return String(format: "%.0f mi", rounded)
        }

        return String(format: "%.1f mi", miles)
    }

    private func primaryHighlight(for leg: TripLeg) -> String? {
        if let firstHighlight = leg.highlights.first, !firstHighlight.isEmpty {
            return firstHighlight
        }

        if let notes = leg.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
            return notes
        }

        return nil
    }

    private var communityPulse: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Community Pulse")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {}) {
                    Label("Visit The Community Hub", systemImage: "person.2.wave.2")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: contentColumns, alignment: .leading, spacing: 16) {
                DashboardCard(title: "Snapshot Reel", subtitle: "Latest Community Photos", accent: accentGradient) {
                    VStack(alignment: .leading, spacing: 12) {
                        photoGrid
                        Button(action: {}) {
                            Label("Open Gallery Soon", systemImage: "photo.on.rectangle")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                DashboardCard(title: "Rig Roll Call", subtitle: "Community Stats", accent: accentGradient) {
                    VStack(alignment: .leading, spacing: 12) {
                        statRow(label: "Rigs on the Road", value: "84", footnote: "+6 this week")
                        statRow(label: "Check-ins Today", value: "128", footnote: "Most Popular: Plaza Walk")
                        statRow(label: "Campfire RSVPs", value: "42", footnote: "🔥 Bring a chair!")
                        Button(action: {}) {
                            Text("See more stats & leaderboards")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                DashboardCard(title: "Community Chat", subtitle: "Latest Discussion Activity", accent: accentGradient) {
                    VStack(alignment: .leading, spacing: 12) {
                        discussionRow(topic: "Same stuff", detail: "Our retro forum is being polished — soon you'll reply and react right here!", timeAgo: "Just now")
                        discussionRow(topic: "Campfire Recipes", detail: "What are you cooking next weekend?", timeAgo: "2h ago")
                        discussionRow(topic: "Route Planning", detail: "Share your favorite scenic drives.", timeAgo: "5h ago")
                        Button(action: {}) {
                            Label("Discussion Hub Coming Soon", systemImage: "bubble.left.and.bubble.right")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var parksPreview: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Parks Visited By Membership")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink(destination: ParksView()) {
                    Label("Browse All Parks", systemImage: "leaf")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    parkCard(name: "Zion National Park", state: "UT", imageName: "mountain.2.fill")
                    parkCard(name: "Big Bend", state: "TX", imageName: "sun.max.trianglebadge.exclamationmark")
                    parkCard(name: "Yosemite", state: "CA", imageName: "leaf.fill")
                    parkCard(name: "Grand Canyon", state: "AZ", imageName: "globe.americas.fill")
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var photoGrid: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.86, green: 0.73, blue: 0.93))
                .frame(width: 70, height: 100)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.94, green: 0.76, blue: 0.68))
                .frame(width: 70, height: 100)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.72, green: 0.85, blue: 0.86))
                .frame(width: 70, height: 100)
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.4))
                )
                .frame(width: 70, height: 100)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("See more")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color(red: 0.32, green: 0.29, blue: 0.55))
                )
        }
    }

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.black.opacity(0.1))

            HStack(spacing: 0) {
                Button(action: {}) {
                    bottomNavItem(label: "Dashboard", systemImage: "house.fill")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    TripsView(viewModel: tripsViewModel)
                } label: {
                    bottomNavItem(label: "Trips", systemImage: "map")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ParksView()
                } label: {
                    bottomNavItem(label: "Parks", systemImage: "leaf")
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    bottomNavItem(label: "Hub", systemImage: "person.3")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    ChecklistsView(viewModel: checklistsViewModel)
                } label: {
                    bottomNavItem(label: "Checklists", systemImage: "checklist")
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    bottomNavItem(label: "Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 28)
            .background(.ultraThinMaterial)
        }
        .background(Color.white.opacity(0.9))
    }

    private func bottomNavItem(label: String, systemImage: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.title3)
            Text(label)
                .font(.footnote)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
        .frame(maxWidth: .infinity)
    }

    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color(red: 0.69, green: 0.86, blue: 0.92).opacity(0.45))
                .offset(x: 16, y: 18)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color(red: 0.22, green: 0.18, blue: 0.39), lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 16) {
                // Removed repetitive "Camp In Style" and "Full-Time RV Life Made Easy" text
                // Now starts directly with Waypoint Wheels title
                VStack(alignment: .leading, spacing: 12) {
                    Text("Waypoint Wheels")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.12, green: 0.11, blue: 0.23))
                        .tracking(2)
                    Text("Camp in style and keep your crew rolling in sync across every adventure.")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 16) {
                    Button(action: {}) {
                        Label("Plan Your Next Stop", systemImage: "suitcase.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(heroAccentGradient, in: Capsule())
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Button(action: {}) {
                        Label("Community Hub", systemImage: "person.3.sequence.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.9), in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 0.25, green: 0.22, blue: 0.45).opacity(0.4), lineWidth: 1.5)
                            )
                            .foregroundStyle(Color(red: 0.25, green: 0.22, blue: 0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 52)
            .padding(.horizontal, 28)
            .padding(.bottom, 32)
        }
        .overlay(alignment: .topLeading) {
            // Keep the blue oval badge - this stays!
            Capsule(style: .continuous)
                .fill(heroAccentGradient)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .frame(width: 200, height: 56)
                .overlay(
                    VStack(spacing: 2) {
                        Text("Waypoint Wheels")
                            .font(.callout)
                            .fontWeight(.heavy)
                            .tracking(3)
                        Text("Camp In Style")
                            .font(.caption2)
                            .tracking(4)
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                )
                .offset(x: 28, y: -18)
        }
        .padding(.top, 18)
    }

    @ViewBuilder
    private var heroProfile: some View {
        if isCompactWidth {
            VStack(alignment: .leading, spacing: 14) {
                Text("Let's get this show on the road!")
                    .font(.footnote)
                    .foregroundColor(Color(red: 0.28, green: 0.23, blue: 0.52))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.82),
                        Color(red: 0.96, green: 0.82, blue: 0.74)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.94, green: 0.77, blue: 0.69), lineWidth: 1.5)
                    )
                    .frame(maxWidth: 220, minHeight: 48)
                    .overlay(
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Account Profile")
                                    .font(.caption2)
                                    .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.44))
                            }
                            .foregroundColor(Color(red: 0.28, green: 0.23, blue: 0.52))
                        }
                        .padding(.horizontal, 14)
                    )
            }
        } else {
            VStack(alignment: .trailing, spacing: 14) {
                Text("Let's get this show on the road!")
                    .font(.footnote)
                    .foregroundColor(Color(red: 0.28, green: 0.23, blue: 0.52))
                    .frame(maxWidth: 180)
                    .multilineTextAlignment(.trailing)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [
                        Color(red: 1.0, green: 0.95, blue: 0.82),
                        Color(red: 0.96, green: 0.82, blue: 0.74)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.94, green: 0.77, blue: 0.69), lineWidth: 1.5)
                    )
                    .frame(width: 200, height: 56)
                    .overlay(
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Account Profile")
                                    .font(.caption2)
                                    .foregroundStyle(Color(red: 0.44, green: 0.35, blue: 0.44))
                            }
                            .foregroundColor(Color(red: 0.28, green: 0.23, blue: 0.52))
                        }
                        .padding(.horizontal, 16)
                    )
            }
        }
    }

    @ViewBuilder
    private func debugPayloadCard(payload: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 2)

            Text("Response Payload")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(payload)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(maxHeight: 150)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func dashboardTile(title: String, value: String, detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(Color(red: 0.32, green: 0.29, blue: 0.55))
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.secondary)
            }
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func timelineRow(title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 24)
                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }

    private func checklistRow(item: Checklist.Item) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isComplete ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.footnote)
                    .foregroundStyle(.primary)

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.footnote)
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var featuredChecklistSubtitle: String {
        if let title = checklistsViewModel.featuredChecklist?.title, !title.isEmpty {
            return title
        }

        return "Your travel tasks"
    }

    private func statRow(label: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Text(footnote)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Divider()
                .opacity(0.2)
        }
    }

    private func discussionRow(topic: String, detail: String, timeAgo: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(topic)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(timeAgo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Divider()
                .opacity(0.2)
        }
    }

    private func parkCard(name: String, state: String, imageName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.83, green: 0.74, blue: 0.96), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 180, height: 110)
                .overlay(
                    Image(systemName: imageName)
                        .font(.system(size: 38))
                        .foregroundStyle(Color(red: 0.32, green: 0.29, blue: 0.55).opacity(0.85))
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DashboardCard<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: LinearGradient
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, accent: LinearGradient, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            content
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accent.opacity(0.5), lineWidth: 1)
                )
        )
    }
}

// MARK: - Weather Response Model

/// Response structure from weather.php endpoint
/// Matches the JSON structure returned by the weather API
struct WeatherResponse: Codable {
    let status: String
    let temperatureRounded: Int?
    let headline: String?
    let narrative: String?
    let description: String?
    let resolvedName: String?
    let timezone: String?
    let errorCode: String?
    let message: String?
}

#Preview {
    DashboardView(userName: "Dan")
}
