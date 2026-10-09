import SwiftUI
import AVFoundation

@main
struct MyApp: App {
    init() {
        // Configure audio session asynchronously to prevent main-thread hang warnings
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                try session.setActive(true)
            } catch {
                print("Failed to configure AVAudioSession: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Handle Supabase Google OAuth redirect callback
                    AuthService.shared.handleOAuthCallback(url)
                }
        }
    }
}
