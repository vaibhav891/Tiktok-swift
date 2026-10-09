import SwiftUI
import AVKit
import AVFoundation

/// A high-performance full-screen TikTok-style looped video player with Liquid Glass pause indicator,
/// double-tap heart bursts, and responsive AVPlayer lifecycle management.
public struct TikTokVideoPlayer: View {
    public let url: URL
    public let isActive: Bool
    public let onDoubleTapLike: () -> Void

    @State private var player: AVPlayer? = nil
    @State private var endObserver: NSObjectProtocol? = nil
    @State private var isPlaying: Bool = true
    @State private var showPlayPauseIcon: Bool = false
    @State private var heartBursts: [HeartBurst] = []

    struct HeartBurst: Identifiable {
        let id = UUID()
        let position: CGPoint
    }

    public init(url: URL, isActive: Bool, onDoubleTapLike: @escaping () -> Void) {
        self.url = url
        self.isActive = isActive
        self.onDoubleTapLike = onDoubleTapLike
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let player = player {
                    PlayerLayerView(player: player)
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .tint(.white)
                }

                // Pause indicator overlay
                if !isPlaying && showPlayPauseIcon {
                    Image(systemName: "play.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(24)
                        .liquidGlassCircle(isClear: true)
                        .transition(.scale.combined(with: .opacity))
                }

                // Double-tap hearts
                ForEach(heartBursts) { burst in
                    HeartBurstView(position: burst.position)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        // Double tap: spawn heart burst and trigger like
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        spawnHeart(at: center)
                        onDoubleTapLike()
                    }
                    .exclusively(before: TapGesture(count: 1).onEnded {
                        // Single tap: toggle play / pause
                        togglePlayPause()
                    })
            )
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                player?.play()
                isPlaying = true
            } else {
                player?.pause()
                isPlaying = false
            }
        }
    }

    private func setupPlayer() {
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        newPlayer.actionAtItemEnd = .none
        newPlayer.automaticallyWaitsToMinimizeStalling = true

        // Clean looping via NotificationCenter
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak newPlayer] _ in
            newPlayer?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            newPlayer?.play()
        }

        self.player = newPlayer

        if isActive {
            newPlayer.play()
            isPlaying = true
        } else {
            isPlaying = false
        }
    }

    private func teardownPlayer() {
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
            endObserver = nil
        }
        player?.pause()
        player = nil
    }

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            withAnimation(.easeInOut(duration: 0.2)) {
                showPlayPauseIcon = true
            }
        } else {
            player.play()
            isPlaying = true
            withAnimation(.easeInOut(duration: 0.2)) {
                showPlayPauseIcon = false
            }
        }
    }

    private func spawnHeart(at position: CGPoint) {
        let burst = HeartBurst(position: position)
        heartBursts.append(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            heartBursts.removeAll(where: { $0.id == burst.id })
        }
    }
}

/// UIViewRepresentable providing a zero-overhead full-frame AVPlayerLayer with resizeAspectFill
public struct PlayerLayerView: UIViewRepresentable {
    public let player: AVPlayer

    public func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    public func updateUIView(_ uiView: PlayerUIView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }

    public class PlayerUIView: UIView {
        public override static var layerClass: AnyClass {
            return AVPlayerLayer.self
        }

        public var playerLayer: AVPlayerLayer {
            return layer as! AVPlayerLayer
        }

        public override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer.frame = bounds
        }
    }
}

/// Floating heart burst animation on double tap
private struct HeartBurstView: View {
    let position: CGPoint
    @State private var scale: CGFloat = 0.2
    @State private var opacity: Double = 1.0
    @State private var offsetY: CGFloat = 0
    @State private var rotationAngle: Double = Double.random(in: -20...20)

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80))
            .foregroundStyle(
                LinearGradient(
                    colors: [.pink, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: .red.opacity(0.6), radius: 12)
            .rotationEffect(.degrees(rotationAngle))
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(y: offsetY)
            .position(position)
            .onAppear {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    scale = 1.2
                }
                withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
                    opacity = 0
                    offsetY = -60
                    scale = 1.4
                }
            }
    }
}
