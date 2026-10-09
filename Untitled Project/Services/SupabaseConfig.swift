import Foundation

/// Holds configuration details for the Supabase backend.
/// You can update `projectURL` and `anonKey` with your own Supabase project values.
public enum SupabaseConfig {
    /// Supabase Project URL (e.g., "https://xyzcompany.supabase.co")
    public static var projectURL: String = "https://your-project.supabase.co"

    /// Supabase Anonymous Public Key
    public static var anonKey: String = "your-anon-key-placeholder"

    /// Custom URL scheme registered for OAuth redirect callbacks (e.g. "myapp://auth/callback")
    public static var redirectScheme: String = "myapp"
    public static var redirectCallbackURL: String = "myapp://auth/callback"

    /// Supabase Storage bucket for video uploads
    public static var videoBucket: String = "videos"

    /// Checks if the user has provided real Supabase credentials.
    public static var isConfigured: Bool {
        return !projectURL.contains("your-project") &&
               !anonKey.contains("your-anon-key") &&
               !projectURL.isEmpty &&
               !anonKey.isEmpty
    }

    /// Full URL for Google OAuth via Supabase Auth
    public static var googleOAuthURL: URL? {
        guard let base = URL(string: projectURL) else { return nil }
        var components = URLComponents(url: base.appendingPathComponent("auth/v1/authorize"), resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "provider", value: "google"),
            URLQueryItem(name: "redirect_to", value: redirectCallbackURL)
        ]
        return components?.url
    }
}
