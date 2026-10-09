import SwiftUI

/// Comments drawer for a video post with Liquid Glass styling and Google Auth protection.
public struct CommentSheetView: View {
    public let postID: String
    var feedService: VideoFeedService = .shared
    var authService: AuthService = .shared

    @State private var commentText: String = ""
    @State private var showingAuthPrompt: Bool = false

    public init(postID: String) {
        self.postID = postID
    }

    private var comments: [Comment] {
        feedService.commentsByPost[postID] ?? []
    }

    public var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("\(comments.count) Comments")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.15))

                // Comments List
                if comments.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("No comments yet")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Be the first to share what you think!")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(comments) { comment in
                                commentRow(comment)
                            }
                        }
                        .padding(20)
                    }
                }

                // Comment input bar
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.15))

                    HStack(spacing: 12) {
                        TextField(
                            authService.isAuthenticated ? "Add a comment..." : "Sign in to comment...",
                            text: $commentText
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)

                        Button {
                            handleSendComment()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(commentText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .pink)
                        }
                        .disabled(commentText.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingAuthPrompt) {
            AuthSheetView(promptMessage: "Sign in with Google to post your comment.")
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: comment.author.avatarURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray)
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(comment.author.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.7))

                Text(comment.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)

                Text(timeAgoString(from: comment.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Button {
                // Like comment
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                        .font(.caption)
                        .foregroundStyle(comment.isLiked ? .red : .white.opacity(0.6))
                    if comment.likesCount > 0 {
                        Text("\(comment.likesCount)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
    }

    private func handleSendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        guard let user = authService.currentUser else {
            showingAuthPrompt = true
            return
        }

        feedService.addComment(postID: postID, text: trimmed, user: user)
        commentText = ""
    }

    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
