import SwiftUI
import PhotosUI
import AVKit

/// Screen for creating and uploading a new video post to Supabase, requiring Google authentication.
public struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    var authService: AuthService = .shared
    var feedService: VideoFeedService = .shared

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedVideoURL: URL? = nil
    @State private var caption: String = ""
    @State private var selectedTags: [String] = ["#fyp", "#viral"]
    @State private var isUploading: Bool = false
    @State private var uploadSuccess: Bool = false
    @State private var previewPlayer: AVPlayer? = nil

    private let availableTags = ["#fyp", "#viral", "#dance", "#music", "#swiftui", "#travel", "#comedy"]

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Video Picker / Preview Area
                        videoSelectionArea

                        // Caption & Hashtags Card
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Caption & Description")
                                .font(.headline)
                                .foregroundStyle(.white)

                            TextField("Describe your video with #hashtags...", text: $caption, axis: .vertical)
                                .lineLimit(3...6)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)

                            // Quick Hashtags
                            Text("Suggested Tags")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.6))

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableTags, id: \.self) { tag in
                                        Button {
                                            toggleTag(tag)
                                        } label: {
                                            Text(tag)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(selectedTags.contains(tag) ? Color.pink.opacity(0.8) : Color.white.opacity(0.12))
                                                .foregroundStyle(.white)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(20)
                        .liquidGlassCard(cornerRadius: 24, isClear: false)

                        // Posting User Status Pill
                        if let user = authService.currentUser {
                            HStack(spacing: 10) {
                                AsyncImage(url: user.avatarURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.circle.fill")
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Posting as \(user.displayName)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                    Text("@\(user.username)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .liquidGlassPill(isClear: false)
                        }

                        // Post Button
                        Button {
                            handlePost()
                        } label: {
                            HStack(spacing: 10) {
                                if isUploading {
                                    ProgressView().tint(.white)
                                    Text("Uploading to Supabase...")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title3)
                                    Text("Post Video")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .shadow(color: .pink.opacity(0.4), radius: 10)
                        }
                        .disabled(selectedVideoURL == nil || isUploading)
                        .opacity(selectedVideoURL == nil ? 0.5 : 1.0)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    await loadVideoFromItem(newItem)
                }
            }
            .alert("Posted Successfully!", isPresented: $uploadSuccess) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Your video has been published to the feed!")
            }
        }
    }

    private var videoSelectionArea: some View {
        VStack(spacing: 14) {
            if let videoURL = selectedVideoURL {
                ZStack(alignment: .topTrailing) {
                    if let player = previewPlayer {
                        VideoPlayer(player: player)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    Button {
                        selectedVideoURL = nil
                        previewPlayer?.pause()
                        previewPlayer = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(Circle().fill(.black.opacity(0.6)))
                    }
                    .padding(12)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.pink)

                    Text("Select a video to share")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedItem, matching: .videos) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose Video")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                        }

                        // Simulator demo quick-picker
                        Button {
                            loadDemoVideo()
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Use Demo Clip")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.pink.opacity(0.3))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .liquidGlassCard(cornerRadius: 24, isClear: false)
            }
        }
    }

    private func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.removeAll(where: { $0 == tag })
        } else {
            selectedTags.append(tag)
        }
    }

    private func loadDemoVideo() {
        let urls = SampleVideoGenerator.shared.ensureSampleVideosExist()
        let sampleURL = urls.first ?? URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8")!
        self.selectedVideoURL = sampleURL
        self.previewPlayer = AVPlayer(url: sampleURL)
        self.previewPlayer?.play()
        if caption.isEmpty {
            caption = "Testing out our new Supabase video feed! Check out this high adrenaline footage. #fyp #viral"
        }
    }

    private func loadVideoFromItem(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        do {
            if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                self.selectedVideoURL = movie.url
                self.previewPlayer = AVPlayer(url: movie.url)
                self.previewPlayer?.play()
            }
        } catch {
            print("Failed to load video: \(error)")
        }
    }

    private func handlePost() {
        guard let videoURL = selectedVideoURL, let user = authService.currentUser else { return }
        isUploading = true

        let fullCaption = caption + " " + selectedTags.joined(separator: " ")

        Task {
            let success = await feedService.uploadNewPost(
                videoURL: videoURL,
                caption: fullCaption.trimmingCharacters(in: .whitespaces),
                author: user
            )
            isUploading = false
            if success {
                uploadSuccess = true
            }
        }
    }
}

/// Helper transferable for PhotosPicker videos
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory
            let targetURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
            try? FileManager.default.removeItem(at: targetURL)
            try FileManager.default.copyItem(at: received.file, to: targetURL)
            return Self(url: targetURL)
        }
    }
}
