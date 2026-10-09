import Foundation
import SwiftUI
import AuthenticationServices
import Observation

/// Service managing user authentication, Google Sign-In via Supabase OAuth, and guest mode.
@Observable
@MainActor
public final class AuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = AuthService()

    public var currentUser: UserProfile? = nil
    public var isAuthenticating: Bool = false
    public var authError: String? = nil
    public var showAuthModal: Bool = false

    /// Action pending completion once sign-in succeeds
    public var pendingAction: (() -> Void)? = nil

    public var isAuthenticated: Bool {
        currentUser != nil
    }

    private let userDefaultsKey = "com.myapp.auth.currentUser"

    public override init() {
        super.init()
        loadPersistedSession()
    }

    /// Checks if a user is logged in. If not, presents the Google sign-in modal.
    public func requireAuth(perform action: @escaping () -> Void) {
        if isAuthenticated {
            action()
        } else {
            pendingAction = action
            showAuthModal = true
        }
    }

    /// Sign in with Google using ASWebAuthenticationSession / Supabase OAuth or mock fallback.
    public func signInWithGoogle() async {
        isAuthenticating = true
        authError = nil

        // If Supabase credentials are configured, launch web authentication session.
        if SupabaseConfig.isConfigured, let authURL = SupabaseConfig.googleOAuthURL {
            await performSupabaseOAuth(authURL: authURL)
        } else {
            // Demo mode fallback: simulate Google Sign-In with realistic network delay
            do {
                try await Task.sleep(nanoseconds: 800_000_000)
                let demoUser = UserProfile(
                    id: "usr_google_\(Int.random(in: 1000...9999))",
                    username: "google_creator",
                    displayName: "Alex Rivera",
                    avatarURL: URL(string: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80"),
                    bio: "SwiftUI & Video Creator 🎬",
                    followerCount: 120,
                    followingCount: 35,
                    likesCount: 890,
                    isFollowing: false
                )
                self.currentUser = demoUser
                self.persistSession(user: demoUser)
                self.isAuthenticating = false
                self.showAuthModal = false

                // Trigger any pending action that requested authentication
                let action = self.pendingAction
                self.pendingAction = nil
                action?()
            } catch {
                self.isAuthenticating = false
                self.authError = error.localizedDescription
            }
        }
    }

    /// Perform ASWebAuthenticationSession for Supabase Google OAuth
    private func performSupabaseOAuth(authURL: URL) async {
        await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: SupabaseConfig.redirectScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }

                    if let error = error {
                        let nsError = error as NSError
                        if nsError.code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                            self.authError = error.localizedDescription
                        }
                        self.isAuthenticating = false
                        continuation.resume()
                        return
                    }

                    if let callbackURL = callbackURL {
                        self.handleOAuthCallback(callbackURL)
                    }

                    self.isAuthenticating = false
                    continuation.resume()
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }

    /// Handles OAuth callback URL parsing
    public func handleOAuthCallback(_ url: URL) {
        guard let fragment = url.fragment ?? url.query else { return }
        let params = parseQueryString(fragment)

        if let accessToken = params["access_token"] {
            // Create user from token or defaults
            let userId = params["sub"] ?? UUID().uuidString
            let user = UserProfile(
                id: userId,
                username: "user_\(userId.prefix(6))",
                displayName: "Google User",
                avatarURL: URL(string: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80"),
                bio: "Welcome to my video feed!",
                followerCount: 0,
                followingCount: 0,
                likesCount: 0,
                isFollowing: false
            )
            self.currentUser = user
            self.persistSession(user: user)
            self.showAuthModal = false

            let action = self.pendingAction
            self.pendingAction = nil
            action?()
            _ = accessToken
        }
    }

    public func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    private func persistSession(user: UserProfile) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    private func loadPersistedSession() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        }
    }

    private func parseQueryString(_ query: String) -> [String: String] {
        var result = [String: String]()
        let pairs = query.components(separatedBy: "&")
        for pair in pairs {
            let elements = pair.components(separatedBy: "=")
            if elements.count == 2 {
                let key = elements[0]
                let value = elements[1].removingPercentEncoding ?? elements[1]
                result[key] = value
            }
        }
        return result
    }

    // MARK: - ASWebAuthenticationPresentationContextProviding
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
