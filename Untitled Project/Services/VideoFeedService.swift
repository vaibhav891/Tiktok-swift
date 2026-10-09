import Foundation
import Observation

/// Service managing video feed posts, interactions (likes, comments), and video upload with Supabase.
@Observable
@MainActor
public final class VideoFeedService {
    public static let shared = VideoFeedService()

    public var posts: [VideoPost] = []
    public var isLoading: Bool = false
    public var errorMessage: String? = nil
    public var commentsByPost: [String: [Comment]] = [:]

    public init() {
        loadInitialFeed()
    }

    /// Loads initial video feed. Checks Supabase if configured, otherwise falls back to guaranteed local + verified sample videos.
    public func loadInitialFeed() {
        if SupabaseConfig.isConfigured {
            Task {
                await fetchFeedFromSupabase()
            }
        } else {
            self.posts = Self.buildMockPosts()
            self.commentsByPost = Self.mockComments
        }
    }

    /// Fetches posts from Supabase REST API `GET /rest/v1/posts?select=*,profiles(*)`
    public func fetchFeedFromSupabase() async {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/posts?select=*&order=created_at.desc") else {
            return
        }

        isLoading = true
        errorMessage = nil

        var request = URLRequest(url: url)
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601

                struct RemotePost: Decodable {
                    let id: String
                    let videoUrl: String
                    let thumbnailUrl: String?
                    let caption: String
                    let soundTitle: String?
                    let likesCount: Int?
                    let commentsCount: Int?
                    let sharesCount: Int?
                    let authorId: String
                    let authorName: String?
                    let authorAvatar: String?
                }

                let remotePosts = try decoder.decode([RemotePost].self, from: data)
                if !remotePosts.isEmpty {
                    self.posts = remotePosts.compactMap { r in
                        guard let vURL = URL(string: r.videoUrl) else { return nil }
                        let author = UserProfile(
                            id: r.authorId,
                            username: r.authorName ?? "creator",
                            displayName: r.authorName ?? "Creator",
                            avatarURL: r.authorAvatar.flatMap { URL(string: $0) }
                        )
                        return VideoPost(
                            id: r.id,
                            videoURL: vURL,
                            thumbnailURL: r.thumbnailUrl.flatMap { URL(string: $0) },
                            caption: r.caption,
                            soundTitle: r.soundTitle ?? "Original Sound",
                            author: author,
                            likesCount: r.likesCount ?? 0,
                            commentsCount: r.commentsCount ?? 0,
                            sharesCount: r.sharesCount ?? 0
                        )
                    }
                }
            } else {
                if self.posts.isEmpty {
                    self.posts = Self.buildMockPosts()
                }
            }
        } catch {
            self.errorMessage = error.localizedDescription
            if self.posts.isEmpty {
                self.posts = Self.buildMockPosts()
            }
        }

        isLoading = false
    }

    /// Toggles like for a post (optimistic update + remote sync)
    public func toggleLike(for postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        let currentStatus = posts[index].isLiked
        posts[index].isLiked.toggle()
        posts[index].likesCount += currentStatus ? -1 : 1

        if SupabaseConfig.isConfigured {
            Task {
                await syncLikeToSupabase(postID: postID, liked: !currentStatus)
            }
        }
    }

    /// Toggles bookmark for a post
    public func toggleBookmark(for postID: String) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[index].isBookmarked.toggle()
    }

    /// Adds a comment to a video post
    public func addComment(postID: String, text: String, user: UserProfile) {
        let newComment = Comment(
            id: UUID().uuidString,
            postID: postID,
            author: user,
            text: text,
            createdAt: Date()
        )

        var existing = commentsByPost[postID] ?? []
        existing.insert(newComment, at: 0)
        commentsByPost[postID] = existing

        if let index = posts.firstIndex(where: { $0.id == postID }) {
            posts[index].commentsCount += 1
        }

        if SupabaseConfig.isConfigured {
            Task {
                await syncCommentToSupabase(comment: newComment)
            }
        }
    }

    /// Uploads a new video post to Supabase and adds it to the active feed
    public func uploadNewPost(videoURL: URL, caption: String, author: UserProfile) async -> Bool {
        isLoading = true

        var finalVideoURL = videoURL
        if SupabaseConfig.isConfigured {
            if let uploadedURL = await uploadVideoFileToStorage(fileURL: videoURL) {
                finalVideoURL = uploadedURL
            }
        }

        let newPost = VideoPost(
            id: UUID().uuidString,
            videoURL: finalVideoURL,
            caption: caption,
            soundTitle: "\(author.displayName) - Original Audio",
            author: author,
            likesCount: 0,
            commentsCount: 0,
            sharesCount: 0,
            isLiked: false,
            createdAt: Date()
        )

        self.posts.insert(newPost, at: 0)

        if SupabaseConfig.isConfigured {
            await insertPostToSupabase(post: newPost)
        }

        isLoading = false
        return true
    }

    // MARK: - Private Supabase Sync Helpers

    private func uploadVideoFileToStorage(fileURL: URL) async -> URL? {
        let filename = "\(UUID().uuidString).mp4"
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/\(SupabaseConfig.videoBucket)/\(filename)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")

        do {
            let data = try Data(contentsOf: fileURL)
            let (_, response) = try await URLSession.shared.upload(for: request, from: data)
            if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                return URL(string: "\(SupabaseConfig.projectURL)/storage/v1/object/public/\(SupabaseConfig.videoBucket)/\(filename)")
            }
        } catch {
            print("Failed video upload: \(error)")
        }
        return nil
    }

    private func insertPostToSupabase(post: VideoPost) async {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/posts") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "id": post.id,
            "video_url": post.videoURL.absoluteString,
            "caption": post.caption,
            "sound_title": post.soundTitle,
            "author_id": post.author.id,
            "author_name": post.author.displayName,
            "author_avatar": post.author.avatarURL?.absoluteString ?? "",
            "created_at": ISO8601DateFormatter().string(from: post.createdAt)
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            _ = try? await URLSession.shared.upload(for: request, from: data)
        }
    }

    private func syncLikeToSupabase(postID: String, liked: Bool) async {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/rpc/toggle_like") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["post_id": postID, "is_liked": liked] as [String : Any]
        if let data = try? JSONSerialization.data(withJSONObject: body) {
            _ = try? await URLSession.shared.upload(for: request, from: data)
        }
    }

    private func syncCommentToSupabase(comment: Comment) async {
        guard let url = URL(string: "\(SupabaseConfig.projectURL)/rest/v1/comments") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "id": comment.id,
            "post_id": comment.postID,
            "author_id": comment.author.id,
            "author_name": comment.author.displayName,
            "text": comment.text
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            _ = try? await URLSession.shared.upload(for: request, from: data)
        }
    }

    // MARK: - Sample Video Factory

    /// Builds mock posts with guaranteed instant local generated 9:16 portrait videos plus tested streaming clips.
    public static func buildMockPosts() -> [VideoPost] {
        let generatedURLs = SampleVideoGenerator.shared.ensureSampleVideosExist()

        let localURL1 = generatedURLs.indices.contains(0) ? generatedURLs[0] : URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
        let localURL2 = generatedURLs.indices.contains(1) ? generatedURLs[1] : URL(string: "https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4")!
        let localURL3 = generatedURLs.indices.contains(2) ? generatedURLs[2] : URL(string: "https://test-videos.co.uk/vids/bigbuckbunny/mp4/h264/720/Big_Buck_Bunny_720_10s_1MB.mp4")!

        return [
            VideoPost(
                id: "post_01",
                videoURL: localURL1,
                thumbnailURL: nil,
                caption: "Golden hour sunset vibes! 🌅✨ Seamless Liquid Glass UI on iOS. #swiftui #liquidglass #fyp",
                soundTitle: "Mountain Echoes - Original Mix",
                author: UserProfile(
                    id: "usr_01",
                    username: "mountain_voyager",
                    displayName: "Sierra Wild 🏔️",
                    avatarURL: URL(string: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80"),
                    bio: "Exploring every ridge and peak 🌲",
                    followerCount: 52000,
                    followingCount: 120,
                    likesCount: 780000,
                    isFollowing: false
                ),
                likesCount: 48200,
                commentsCount: 632,
                sharesCount: 1420,
                isLiked: false,
                isBookmarked: false
            ),
            VideoPost(
                id: "post_02",
                videoURL: localURL2,
                thumbnailURL: nil,
                caption: "Coastal escape flow 🌊 Deep blues and ambient rhythms. Turn your sound on! #ocean #relax #traveltok",
                soundTitle: "Pacific Waves & Ambient Lo-Fi",
                author: UserProfile(
                    id: "usr_02",
                    username: "coastal_curator",
                    displayName: "Noah Ocean 🌊",
                    avatarURL: URL(string: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80"),
                    bio: "Chasing swells and tides worldwide 🏄‍♂️",
                    followerCount: 110000,
                    followingCount: 430,
                    likesCount: 1430000,
                    isFollowing: true
                ),
                likesCount: 128400,
                commentsCount: 2310,
                sharesCount: 8900,
                isLiked: true,
                isBookmarked: true
            ),
            VideoPost(
                id: "post_03",
                videoURL: localURL3,
                thumbnailURL: nil,
                caption: "Building smooth 60fps animations with Liquid Glass in SwiftUI! ✨💻 Drop a comment for the code! #coding #ios #dev",
                soundTitle: "Synthwave Code Beats",
                author: UserProfile(
                    id: "usr_03",
                    username: "swift_dev_ninja",
                    displayName: "Maya Code 💻",
                    avatarURL: URL(string: "https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80"),
                    bio: "Crafting beautiful iOS apps daily 🚀",
                    followerCount: 84000,
                    followingCount: 215,
                    likesCount: 940000,
                    isFollowing: false
                ),
                likesCount: 91300,
                commentsCount: 1140,
                sharesCount: 4200,
                isLiked: false,
                isBookmarked: false
            ),
            VideoPost(
                id: "post_04",
                videoURL: URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!,
                thumbnailURL: nil,
                caption: "Apple HLS Adaptive Stream testing 📺 Live bitrate switching in action! #streaming #apple #tech",
                soundTitle: "Apple Test Stream Audio",
                author: UserProfile(
                    id: "usr_04",
                    username: "stream_lab",
                    displayName: "Media Lab 🧪",
                    avatarURL: URL(string: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80"),
                    bio: "Testing ultra-low latency playback",
                    followerCount: 31000,
                    followingCount: 95,
                    likesCount: 240000,
                    isFollowing: false
                ),
                likesCount: 15400,
                commentsCount: 340,
                sharesCount: 920,
                isLiked: false,
                isBookmarked: false
            )
        ]
    }

    public static let mockComments: [String: [Comment]] = [
        "post_01": [
            Comment(
                postID: "post_01",
                author: UserProfile(username: "adventure_dave", displayName: "Dave Miller"),
                text: "The colors here are absolutely unreal! What camera did you use?"
            ),
            Comment(
                postID: "post_01",
                author: UserProfile(username: "elena_travels", displayName: "Elena R."),
                text: "Added this spot to my bucket list immediately 🙌"
            )
        ],
        "post_02": [
            Comment(
                postID: "post_02",
                author: UserProfile(username: "surf_life", displayName: "Kai Walker"),
                text: "That water clarity is unreal! 🔥"
            )
        ],
        "post_03": [
            Comment(
                postID: "post_03",
                author: UserProfile(username: "app_creator", displayName: "Liam Chen"),
                text: "Liquid Glass looks so futuristic and smooth! Need this tutorial ASAP."
            )
        ]
    ]
}
