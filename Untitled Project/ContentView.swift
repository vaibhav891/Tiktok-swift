import SwiftUI

/// Main container view featuring full-screen TikTok video feed and a floating Liquid Glass bottom bar.
struct ContentView: View {
    @State private var selectedTab: Tab = .feed
    @State private var showingCreateSheet: Bool = false
    var authService: AuthService = .shared

    enum Tab {
        case feed
        case discover
        case inbox
        case profile
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            Group {
                switch selectedTab {
                case .feed:
                    FeedView()
                case .discover:
                    discoverView
                case .inbox:
                    inboxView
                case .profile:
                    ProfileView()
                }
            }
            .ignoresSafeArea(edges: selectedTab == .feed ? .all : .top)

            // Floating Liquid Glass Bottom Navigation Bar
            floatingTabBar
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreatePostView()
        }
        .sheet(isPresented: Bindable(authService).showAuthModal) {
            AuthSheetView()
        }
    }

    // MARK: - Floating Liquid Glass Tab Bar

    private var floatingTabBar: some View {
        GlassEffectContainer {
            HStack {
                // Home (Feed)
                tabBarButton(icon: "house.fill", label: "Home", tab: .feed)

                Spacer()

                // Discover
                tabBarButton(icon: "safari.fill", label: "Discover", tab: .discover)

                Spacer()

                // Create Post (+) Button - Requires Login!
                Button {
                    authService.requireAuth {
                        showingCreateSheet = true
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.8), Color.pink.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                            .shadow(color: .pink.opacity(0.4), radius: 6)

                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 4)

                Spacer()

                // Inbox
                tabBarButton(icon: "bubble.left.and.bubble.right.fill", label: "Inbox", tab: .inbox)

                Spacer()

                // Profile
                tabBarButton(icon: "person.fill", label: "Profile", tab: .profile)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .liquidGlassPill(isClear: false)
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
        }
    }

    private func tabBarButton(icon: String, label: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? Color.white : Color.white.opacity(0.45))
            .frame(width: 48)
        }
    }

    // MARK: - Secondary Views

    private var discoverView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Explore Trending")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 60)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(["#LiquidGlass", "#SwiftUI", "#TechTok", "#CinematicNature", "#Creators"], id: \.self) { tag in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "number")
                                        .foregroundStyle(.pink)
                                    Text(tag.replacingOccurrences(of: "#", with: ""))
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text("Trending")
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .liquidGlassPill(isClear: false)
                                        .foregroundStyle(.white.opacity(0.8))
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(1...4, id: \.self) { i in
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 110, height: 160)
                                                .overlay(
                                                    VStack {
                                                        Spacer()
                                                        Text("Clip \(i)")
                                                            .font(.caption2)
                                                            .foregroundStyle(.white)
                                                            .padding(6)
                                                    }
                                                )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private var inboxView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Notifications")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.top, 60)

                Spacer()

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.pink)

                Text("All activity will appear here")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Likes, comments, mentions, and creator updates.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.bottom, 120)
        }
    }
}

#Preview {
    ContentView()
}
