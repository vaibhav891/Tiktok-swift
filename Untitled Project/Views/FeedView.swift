import SwiftUI

/// Main vertical scrolling TikTok-style video feed with Liquid Glass overlays and guest support.
public struct FeedView: View {
    var feedService: VideoFeedService = .shared
    var authService: AuthService = .shared

    @State private var currentFeedType: FeedType = .forYou
    @State private var activeIndex: Int = 0
    @State private var activeCommentPostID: String? = nil
    @State private var shareItem: VideoPost? = nil

    public enum FeedType: String, CaseIterable, Identifiable {
        case following = "Following"
        case forYou = "For You"

        public var id: String { self.rawValue }
    }

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Vertical Paging Feed
                if feedService.posts.isEmpty {
                    emptyFeedView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(feedService.posts.enumerated()), id: \.element.id) { index, post in
                                ZStack {
                                    TikTokVideoPlayer(
                                        url: post.videoURL,
                                        isActive: activeIndex == index,
                                        onDoubleTapLike: {
                                            feedService.toggleLike(for: post.id)
                                        }
                                    )

                                    VideoOverlayView(
                                        post: post,
                                        onLike: {
                                            feedService.toggleLike(for: post.id)
                                        },
                                        onComment: {
                                            activeCommentPostID = post.id
                                        },
                                        onBookmark: {
                                            feedService.toggleBookmark(for: post.id)
                                        },
                                        onShare: {
                                            shareItem = post
                                        },
                                        onProfileTap: {
                                            // Handle profile navigation
                                        }
                                    )
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: Binding<Int?>(
                        get: { activeIndex },
                        set: { if let val = $0 { activeIndex = val } }
                    ))
                    .ignoresSafeArea()
                }

                // Floating Top Liquid Glass Navigation Header
                topNavigationBar
            }
        }
        .sheet(item: Binding<CommentPostWrapper?>(
            get: { activeCommentPostID.map { CommentPostWrapper(id: $0) } },
            set: { activeCommentPostID = $0?.id }
        )) { wrapper in
            CommentSheetView(postID: wrapper.id)
        }
        .sheet(item: $shareItem) { post in
            ShareSheet(activityItems: [post.videoURL, "Check out this video by \(post.author.displayName)!"])
        }
    }

    private var topNavigationBar: some View {
        HStack {
            // Live / Search Button
            Button {
                // Live Stream or Search action
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .liquidGlassCircle(isClear: true)
            }

            Spacer()

            // Floating Pill: "Following" | "For You"
            GlassEffectContainer {
                HStack(spacing: 4) {
                    ForEach(FeedType.allCases) { type in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                currentFeedType = type
                            }
                        } label: {
                            Text(type.rawValue)
                                .font(.subheadline)
                                .fontWeight(currentFeedType == type ? .bold : .medium)
                                .foregroundStyle(currentFeedType == type ? .white : .white.opacity(0.6))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    currentFeedType == type ?
                                    Color.white.opacity(0.18) : Color.clear
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(4)
                .liquidGlassPill(isClear: true)
            }

            Spacer()

            // Supabase / Network indicator
            Button {
                feedService.loadInitialFeed()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .liquidGlassCircle(isClear: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 54) // safe area top clearance
    }

    private var emptyFeedView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                if feedService.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    Text("Loading Supabase Video Feed...")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Image(systemName: "play.slash.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No videos found")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Button("Reload Feed") {
                        feedService.loadInitialFeed()
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .liquidGlassPill(isClear: false)
                }
            }
        }
    }
}

/// Identifiable wrapper for comment sheet binding
struct CommentPostWrapper: Identifiable {
    let id: String
}

/// Native UIKit Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
