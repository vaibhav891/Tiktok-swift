import Foundation

/// Represents a user profile in the application.
public struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var username: String
    public var displayName: String
    public var avatarURL: URL?
    public var bio: String
    public var followerCount: Int
    public var followingCount: Int
    public var likesCount: Int
    public var isFollowing: Bool

    public init(
        id: String = UUID().uuidString,
        username: String,
        displayName: String,
        avatarURL: URL? = nil,
        bio: String = "",
        followerCount: Int = 0,
        followingCount: Int = 0,
        likesCount: Int = 0,
        isFollowing: Bool = false
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.likesCount = likesCount
        self.isFollowing = isFollowing
    }

    public static let sampleUser = UserProfile(
        id: "usr_creator_01",
        username: "sarah_travels",
        displayName: "Sarah Jenkins ✈️",
        avatarURL: URL(string: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80"),
        bio: "Chasing sunsets around the globe 🌍 | Film & travel",
        followerCount: 245000,
        followingCount: 180,
        likesCount: 1890000,
        isFollowing: false
    )
}

/// Represents a video post in the feed.
public struct VideoPost: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let videoURL: URL
    public let thumbnailURL: URL?
    public var caption: String
    public var soundTitle: String
    public var author: UserProfile
    public var likesCount: Int
    public var commentsCount: Int
    public var sharesCount: Int
    public var isLiked: Bool
    public var isBookmarked: Bool
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        videoURL: URL,
        thumbnailURL: URL? = nil,
        caption: String,
        soundTitle: String = "Original Sound",
        author: UserProfile,
        likesCount: Int = 0,
        commentsCount: Int = 0,
        sharesCount: Int = 0,
        isLiked: Bool = false,
        isBookmarked: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.soundTitle = soundTitle
        self.author = author
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.isLiked = isLiked
        self.isBookmarked = isBookmarked
        self.createdAt = createdAt
    }
}

/// Represents a comment on a video post.
public struct Comment: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let postID: String
    public let author: UserProfile
    public let text: String
    public var likesCount: Int
    public var isLiked: Bool
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        postID: String,
        author: UserProfile,
        text: String,
        likesCount: Int = 0,
        isLiked: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.postID = postID
        self.author = author
        self.text = text
        self.likesCount = likesCount
        self.isLiked = isLiked
        self.createdAt = createdAt
    }
}
