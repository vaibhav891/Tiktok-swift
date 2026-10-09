import SwiftUI

/// Overlay containing author details, caption, sound info, and action buttons styled with Liquid Glass.
public struct VideoOverlayView: View {
    public let post: VideoPost
    public let onLike: () -> Void
    public let onComment: () -> Void
    public let onBookmark: () -> Void
    public let onShare: () -> Void
    public let onProfileTap: () -> Void

    @State private var isSpinningRecord: Bool = false
    @State private var isExpandedCaption: Bool = false

    public init(
        post: VideoPost,
        onLike: @escaping () -> Void,
        onComment: @escaping () -> Void,
        onBookmark: @escaping () -> Void,
        onShare: @escaping () -> Void,
        onProfileTap: @escaping () -> Void
    ) {
        self.post = post
        self.onLike = onLike
        self.onComment = onComment
        self.onBookmark = onBookmark
        self.onShare = onShare
        self.onProfileTap = onProfileTap
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Subtle bottom gradient for text contrast over bright videos
            LinearGradient(
                colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            HStack(alignment: .bottom, spacing: 12) {
                // Bottom-left info (Author, Caption, Sound)
                VStack(alignment: .leading, spacing: 8) {
                    // Author username
                    Button(action: onProfileTap) {
                        HStack(spacing: 6) {
                            Text("@\(post.author.username)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)

                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }

                    // Caption
                    Text(post.caption)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(isExpandedCaption ? nil : 2)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpandedCaption.toggle()
                            }
                        }

                    // Sound Track Pill
                    HStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundStyle(.white)

                        Text(post.soundTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .liquidGlassPill(isClear: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right action buttons wrapped in GlassEffectContainer
                GlassEffectContainer {
                    VStack(spacing: 18) {
                        // User Avatar + Follow badge
                        avatarButton

                        // Like button
                        actionButton(
                            icon: post.isLiked ? "heart.fill" : "heart",
                            color: post.isLiked ? .red : .white,
                            count: formatNumber(post.likesCount),
                            action: onLike
                        )

                        // Comment button
                        actionButton(
                            icon: "message.fill",
                            color: .white,
                            count: formatNumber(post.commentsCount),
                            action: onComment
                        )

                        // Bookmark button
                        actionButton(
                            icon: post.isBookmarked ? "bookmark.fill" : "bookmark",
                            color: post.isBookmarked ? .yellow : .white,
                            count: "Save",
                            action: onBookmark
                        )

                        // Share button
                        actionButton(
                            icon: "arrowshape.turn.up.right.fill",
                            color: .white,
                            count: formatNumber(post.sharesCount),
                            action: onShare
                        )

                        // Spinning Music Record
                        spinningRecord
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 90) // clearance for bottom tab bar
        }
    }

    private var avatarButton: some View {
        Button(action: onProfileTap) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: post.author.avatarURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.gray)
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                .liquidGlassCircle(isClear: false)

                // Plus badge
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.pink)
                    .background(Circle().fill(.white).frame(width: 14, height: 14))
                    .offset(y: 8)
            }
        }
        .padding(.bottom, 6)
    }

    private func actionButton(
        icon: String,
        color: Color,
        count: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .liquidGlassCircle(isClear: true)

                Text(count)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }
        }
    }

    private var spinningRecord: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            Circle()
                .fill(LinearGradient(colors: [.gray, .black, .gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 24, height: 24)

            AsyncImage(url: post.author.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note")
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            .clipShape(Circle())
        }
        .rotationEffect(.degrees(isSpinningRecord ? 360 : 0))
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                isSpinningRecord = true
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
