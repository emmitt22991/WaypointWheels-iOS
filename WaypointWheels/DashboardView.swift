import SwiftUI

// MARK: - Dashboard View Implementation Notes
//
// CURRENT STATE:
// ✅ Trip data is fully integrated - displays real next travel day from TripsViewModel
// ✅ Checklist tasks are now correctly filtered to show only TODAY'S tasks from dailyChecklists
// ⚠️  Weather display is DISABLED pending ProfileService implementation
// ⚠️  Current location shows trip start location as fallback until ProfileService exists
//
// IMPLEMENTATION NEEDED - Profile & Weather Service:
//
// The backend (dashboard.php) already has user location via $camperProfile['homeBase']
// and fetches weather using WeatherClient::getCurrentConditions($homeBase).
//
// To complete the dashboard:
//
// 1. CREATE: ProfileService.swift
//    - Method: fetchUserProfile() -> UserProfile
//    - Should call new API endpoint: /api/profile.php
//    - Return struct with: homeBase, weatherTimezone, etc.
//
// 2. CREATE: /api/profile.php endpoint (backend)
//    - Return JSON with camper profile data
//    - Include: home_base, weather_timezone, resolved_location
//
// 3. CREATE: WeatherService.swift
//    - Method: fetchCurrentConditions(location: String) -> WeatherSummary
//    - Should call new API endpoint: /api/weather.php
//    - Return struct matching PHP WeatherClient response
//
// 4. CREATE: /api/weather.php endpoint (backend)
//    - Wrapper around existing WeatherClient class
//    - Accept location parameter
//    - Return weather summary JSON
//
// 5. UPDATE: DashboardView.swift
//    - Add: @StateObject private var profileViewModel = ProfileViewModel()
//    - Add: @StateObject private var weatherViewModel = WeatherViewModel()
//    - In .task: await profileViewModel.loadProfile()
//    - In .task: if let location = profileViewModel.homeBase {
//                  await weatherViewModel.loadWeather(for: location)
//                }
//    - Update computed properties to use real data
//
// BACKEND REFERENCE:
// See dashboard.php lines 13-40 for how homeBase and weather are currently fetched
// See WeatherClient.php for the weather API integration that needs to be exposed

@MainActor
struct DashboardView: View {
    let userName: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var checklistsViewModel = ChecklistsViewModel()
    @StateObject private var tripsViewModel = TripsViewModel()

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
    
    // MARK: - Real Data Computed Properties for "From the Caravan"
    
    /// Current location data - should come from user's home base in their profile
    /// Currently falls back to showing trip start location if available
    private var currentLocationTitle: String {
        // TODO: Priority order once ProfileService is implemented:
        // 1. User's home base from profile (when not traveling)
        // 2. Current trip leg location (when actively traveling)
        // 3. "Set Home Base" prompt
        
        // TEMPORARY: Until we have ProfileService, show trip start location
        if let leg = nextLeg {
            return leg.start.name
        }
        
        return "Set Your Home Base"
    }
    
    private var currentLocationDetail: String {
        // TODO: Once ProfileService exists, check userHomeBase first:
        // if let homeBase = userHomeBase {
        //     return "Holding down the fort at \(homeBase) until the next adventure."
        // }
        
        // TEMPORARY: Show trip context
        if let leg = nextLeg {
            return "The crew is currently at \(leg.start.name) preparing for the next leg."
        }
        
        return "Add your home base in Settings to track your location between trips."
    }
    
    /// Next travel day data - uses real trip itinerary
    private var nextTravelDayValue: String {
        guard let leg = nextLeg else {
            return "No travel planned"
        }
        
        // Use the pre-formatted dateRangeDescription from the API
        // Format is already "Mon · Apr 14" style
        return leg.dateRangeDescription
    }
    
    private var nextTravelDayDetail: String {
        guard let leg = nextLeg else {
            return "Plan your next route to see travel details here."
        }
        
        return "Wheels up soon! You're bound for \(leg.end.name)."
    }
    
    /// Today's vibe/weather - needs profile service integration
    private var todayVibeValue: String {
        // TODO: Once ProfileService is implemented and returns homeBase:
        // 1. Check if userHomeBase has a value
        // 2. If yes, create WeatherService that calls the weather API
        // 3. Fetch weather for userHomeBase location
        // 4. Return formatted temperature and conditions
        //
        // Example future implementation:
        // if let location = userHomeBase {
        //     if let weather = weatherViewModel.currentConditions {
        //         return "\(weather.temperature)° & \(weather.headline)"
        //     }
        //     return "Loading weather..."
        // }
        
        // For now, show the current location as the value
        return currentLocationTitle
    }
    
    private var todayVibeDetail: String {
        // TODO: Once weather is integrated, return the narrative or description
        let location = currentLocationTitle
        
        if location == "Set Your Home Base" {
            return "Add your Home Base in Settings to unlock weather updates."
        }
        
        return "Weather updates coming soon for \(location)."
    }
    
    /// Check if there are any incomplete checklist items scheduled for today
    /// This uses dailyChecklists which contains checklists specifically assigned to today's date
    private var hasTasksToday: Bool {
        // Count all incomplete items across all checklists scheduled for today
        let incompleteCount = checklistsViewModel.dailyChecklists.reduce(0) { count, run in
            count + run.checklist.items.filter({ !$0.isComplete }).count
        }
        
        return incompleteCount > 0
    }
    
    /// Count of incomplete tasks scheduled for today across all daily checklists
    private var tasksTodayCount: Int {
        checklistsViewModel.dailyChecklists.reduce(0) { count, run in
            count + run.checklist.items.filter({ !$0.isComplete }).count
        }
    }
    
    /// Get user's home base location for weather
    /// TODO: Implement profile service to fetch user's home base from backend
    /// For now, this returns nil until we create a ProfileService that calls the profile API
    private var userHomeBase: String? {
        // IMPLEMENTATION NEEDED:
        // 1. Create ProfileService.swift with fetchUserProfile() method
        // 2. Add @StateObject private var profileViewModel = ProfileViewModel()
        // 3. Call profileViewModel.loadProfile() in .task
        // 4. Return profileViewModel.homeBase here
        //
        // The backend already has this data in the camper_profile session variable
        // We need to create an API endpoint like /api/profile.php that returns it
        return nil
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
                                }

                                bottomNavigation
                            }
                        }
                        .task {
                            await tripsViewModel.loadItinerary()
                            await checklistsViewModel.refresh()
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

            // FROM THE CARAVAN - Now with real data
            DashboardCard(title: "From the Caravan", subtitle: "Waypoint Wheels Dashboard", accent: accentGradient) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create plans, track your travels, the community, and what's coming up next.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: heroTileColumns, alignment: .leading, spacing: 16) {
                        // Current Location - using real data
                        dashboardTile(
                            title: "Current Location",
                            value: currentLocationTitle,
                            detail: currentLocationDetail,
                            icon: "mappin.and.ellipse"
                        )
                        
                        // Next Travel Day - using real trip data
                        dashboardTile(
                            title: "Next Travel Day",
                            value: nextTravelDayValue,
                            detail: nextTravelDayDetail,
                            icon: "calendar"
                        )
                        
                        // Today's Vibe/Weather - TODO: integrate weather service
                        dashboardTile(
                            title: "Today",
                            value: todayVibeValue,
                            detail: todayVibeDetail,
                            icon: "sun.max.fill"
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

                // SIMPLIFIED CHECKLIST CARD - only show if there are tasks today
                if hasTasksToday {
                    DashboardCard(title: "Checklist", subtitle: "Tasks Today", accent: accentGradient) {
                        VStack(alignment: .leading, spacing: 12) {
                            // Show count of tasks
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("You have \(tasksTodayCount) task\(tasksTodayCount == 1 ? "" : "s") to do today!")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    
                                    Text("Stay on track by checking off each task.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                            // Link to open checklists
                            NavigationLink {
                                ChecklistsView(viewModel: checklistsViewModel)
                            } label: {
                                Label("Open Your Checklist", systemImage: "list.bullet.rectangle")
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(heroAccentGradient, in: Capsule())
                                    .foregroundColor(.white)
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

    // UPDATED HERO HEADER - Simplified to remove repetitive content
    private var heroHeader: some View {
        ZStack(alignment: .topLeading) {
            // Shadow layer
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color(red: 0.69, green: 0.86, blue: 0.92).opacity(0.45))
                .offset(x: 16, y: 18)

            // Main white card
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(Color.white.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 36, style: .continuous)
                        .stroke(Color(red: 0.22, green: 0.18, blue: 0.39), lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 12)

            // Content - SIMPLIFIED: Start with "Waypoint Wheels" title
            VStack(alignment: .leading, spacing: 16) {
                // Main title and tagline
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

                // Action buttons
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
        // Blue oval badge overlay - KEPT as requested
        .overlay(alignment: .topLeading) {
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

#Preview {
    DashboardView(userName: "Dan")
}
