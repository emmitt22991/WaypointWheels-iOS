import SwiftUI

struct DashboardView: View {
    let userName: String
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var checklistsViewModel = ChecklistsViewModel()
    @State private var showingChecklists = false

    private let accentGradient = LinearGradient(colors: [
        Color(red: 0.98, green: 0.88, blue: 0.63),
        Color(red: 1.0, green: 0.95, blue: 0.82)
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

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [
                Color(red: 0.95, green: 0.96, blue: 0.99),
                Color(red: 0.99, green: 0.95, blue: 0.89)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
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

                bottomNavigation
            }
        }
        .sheet(isPresented: $showingChecklists) {
            ChecklistsView(viewModel: checklistsViewModel)
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
                        dashboardTile(title: "Current Location", value: "New Braunfels, TX", detail: "The crew is hunkered down in New Braunfels, TX waiting out the warm front.", icon: "mappin.and.ellipse")
                        dashboardTile(title: "Next Travel Day", value: "Sunday · Oct 12", detail: "Wheels up soon! You're bound for \nTyson's RV Resort.", icon: "calendar")
                        dashboardTile(title: "Today", value: "63° & Clear Skies", detail: "Expect sunshine with highs near 70°. Winds from the west, 10-15 mph.", icon: "sun.max.fill")
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
                Button(action: {}) {
                    Label("View Trip Calendar", systemImage: "calendar.badge.clock")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: contentColumns, alignment: .leading, spacing: 16) {
                DashboardCard(title: "Next Stop", subtitle: "Austin, TX", accent: accentGradient) {
                    VStack(alignment: .leading, spacing: 8) {
                        timelineRow(title: "Depart", detail: "Mon · 8:00 AM", symbol: "arrow.up.right")
                        timelineRow(title: "Arrive", detail: "Mon · 11:30 AM", symbol: "flag.checkered")
                        Divider().padding(.vertical, 4)
                        Text("Fuel up before you roll out. The weather looks ideal for travel — no storms on the radar.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                DashboardCard(title: "Checklist", subtitle: featuredChecklistSubtitle, accent: accentGradient) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let checklist = checklistsViewModel.featuredChecklist {
                            if checklist.items.isEmpty {
                                Text("Start adding tasks to keep your crew organized.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(checklist.items.prefix(3)) { item in
                                        checklistRow(item: item)
                                    }

                                    if checklist.items.count > 3 {
                                        Text("+\(checklist.items.count - 3) more items")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    Text(checklist.completionSummary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        } else {
                            Text("Build reusable lists for packing, setup, and maintenance. We'll keep them handy here.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button(action: { showingChecklists = true }) {
                            Label("Open Checklists", systemImage: "list.bullet.rectangle")
                                .font(.footnote)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.85), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                    }
                }
            }
        }
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
                Button(action: {}) {
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
                bottomNavItem(label: "Dashboard", systemImage: "house.fill")
                bottomNavItem(label: "Trips", systemImage: "map")
                bottomNavItem(label: "Parks", systemImage: "leaf")
                bottomNavItem(label: "Community", systemImage: "person.3")
                bottomNavItem(label: "Checklists", systemImage: "checklist")
                bottomNavItem(label: "Settings", systemImage: "gearshape")
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Waypoint Wheels")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .tracking(1.5)
            Text("Camp In Style")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var heroProfile: some View {
        if isCompactWidth {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's get this show on the road!")
                    .font(.footnote)
                    .foregroundColor(Color(red: 0.36, green: 0.31, blue: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                Capsule()
                    .fill(accentGradient)
                    .frame(maxWidth: 200, minHeight: 38)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                            Text(userName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.28, green: 0.23, blue: 0.52))
                        }
                        .padding(.horizontal, 8)
                    )
            }
        } else {
            VStack(alignment: .trailing, spacing: 8) {
                Text("Let's get this show on the road!")
                    .font(.footnote)
                    .foregroundColor(Color(red: 0.36, green: 0.31, blue: 0.55))
                    .frame(maxWidth: 160)
                    .multilineTextAlignment(.trailing)
                Capsule()
                    .fill(accentGradient)
                    .frame(width: 130, height: 38)
                    .overlay(
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.52))
                            Text(userName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(red: 0.28, green: 0.23, blue: 0.52))
                        }
                        .padding(.horizontal, 8)
                    )
            }
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

#Preview {
    DashboardView(userName: "Dan")
}
