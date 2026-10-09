import SwiftUI

/// Profile screen displaying user stats, uploaded videos, and Google Sign-In status with Liquid Glass.
public struct ProfileView: View {
    var authService: AuthService = .shared
    var feedService: VideoFeedService = .shared

    @State private var selectedTab: Int = 0
    @State private var showingAuthModal: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let user = authService.currentUser {
                authenticatedProfileView(user)
            } else {
                guestProfileView
            }
        }
        .sheet(isPresented: $showingAuthModal) {
            AuthSheetView(promptMessage: "Sign in with Google to access your creator profile and manage your posts.")
        }
    }

    private func authenticatedProfileView(_ user: UserProfile) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Header actions
                HStack {
                    Text("@\(user.username)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        authService.signOut()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .liquidGlassPill(isClear: false)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Avatar
                AsyncImage(url: user.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.gray)
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                .liquidGlassCircle(isClear: false)

                // Display Name
                Text(user.displayName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                // Bio
                if !user.bio.isEmpty {
                    Text(user.bio)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Stats Bar (Following, Followers, Likes)
                HStack(spacing: 36) {
                    statItem(title: "Following", value: "\(user.followingCount)")
                    statItem(title: "Followers", value: formatNumber(user.followerCount))
                    statItem(title: "Likes", value: formatNumber(user.likesCount))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .liquidGlassCard(cornerRadius: 18, isClear: false)

                // Tab Selector
                HStack(spacing: 40) {
                    tabButton(title: "My Videos", icon: "square.grid.3x3.fill", index: 0)
                    tabButton(title: "Liked", icon: "heart.fill", index: 1)
                    tabButton(title: "Saved", icon: "bookmark.fill", index: 2)
                }
                .padding(.top, 12)

                Divider().background(Color.white.opacity(0.15))

                // Video Grid
                let userPosts = feedService.posts.filter { $0.author.id == user.id }
                if userPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 40)
                        Text("No videos uploaded yet")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Tap the '+' button in the navigation bar to post your first video!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                        ForEach(userPosts) { post in
                            ZStack(alignment: .bottomLeading) {
                                Color.gray.opacity(0.3)
                                    .aspectRatio(9/16, contentMode: .fit)

                                HStack(spacing: 4) {
                                    Image(systemName: "play.fill")
                                        .font(.caption2)
                                    Text("\(post.likesCount)")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.white)
                                .padding(6)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 16)
                }

                Spacer(minLength: 100)
            }
        }
    }

    private var guestProfileView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)

                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)
            }
            .liquidGlassCircle(isClear: false)

            Text("Creator Profile")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("Sign in with Google to post videos, bookmark your favorites, and manage your account.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                showingAuthModal = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)

                    Text("Sign in with Google")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.3), radius: 8)
            }

            Spacer()
        }
        .padding(24)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.4))

                Rectangle()
                    .fill(selectedTab == index ? Color.white : Color.clear)
                    .frame(height: 2)
            }
        }
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }
}
