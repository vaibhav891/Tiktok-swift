import SwiftUI

/// Sign-in sheet presenting Google Sign-In via Supabase Auth with Liquid Glass styling.
public struct AuthSheetView: View {
    @Environment(\.dismiss) private var dismiss
    var authService: AuthService = .shared
    public var promptMessage: String = "Sign in with Google to post your videos, share clips, and interact with the creator community."

    @State private var showingDetails: Bool = false

    public init(promptMessage: String = "Sign in with Google to post your videos, share clips, and interact with the creator community.") {
        self.promptMessage = promptMessage
    }

    public var body: some View {
        ZStack {
            // Background blur / gradient
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Top grab handle
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)

                Spacer()

                // Main card with Liquid Glass
                VStack(spacing: 20) {
                    // App Icon badge
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.pink, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 72, height: 72)

                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .pink.opacity(0.5), radius: 16)

                    Text("Welcome to FeedTok")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text(promptMessage)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    // Google Sign-In Button
                    Button {
                        Task {
                            await authService.signInWithGoogle()
                            if authService.isAuthenticated {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            if authService.isAuthenticating {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "g.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)

                                Text("Continue with Google")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.black)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.2), radius: 8)
                    }
                    .disabled(authService.isAuthenticating)
                    .padding(.top, 8)

                    // Backend Status Info Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(SupabaseConfig.isConfigured ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)

                        Text(SupabaseConfig.isConfigured ? "Supabase Live Connected" : "Supabase Demo Mode Active")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .liquidGlassPill(isClear: false)

                    if let error = authService.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(28)
                .liquidGlassCard(cornerRadius: 28, isClear: false)
                .padding(.horizontal, 20)

                Spacer()

                // Continue as guest button
                Button {
                    dismiss()
                } label: {
                    Text("Continue browsing as Guest")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))
                        .underline()
                }
                .padding(.bottom, 24)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
