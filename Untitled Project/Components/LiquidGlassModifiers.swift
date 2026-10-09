import SwiftUI

/// Reusable modifiers and styles for Apple's Liquid Glass design system.
/// Based on Apple HIG: Liquid Glass floats above content layers,
/// providing clear depth while allowing video media to peek through.
public struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var isClear: Bool

    public init(cornerRadius: CGFloat = 20, isClear: Bool = false) {
        self.cornerRadius = cornerRadius
        self.isClear = isClear
    }

    public func body(content: Content) -> some View {
        content
            .glassEffect(
                isClear ? .clear : .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

public struct LiquidGlassCircleModifier: ViewModifier {
    var isClear: Bool

    public init(isClear: Bool = true) {
        self.isClear = isClear
    }

    public func body(content: Content) -> some View {
        content
            .glassEffect(
                isClear ? .clear : .regular,
                in: Circle()
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

public struct LiquidGlassPillModifier: ViewModifier {
    var isClear: Bool

    public init(isClear: Bool = false) {
        self.isClear = isClear
    }

    public func body(content: Content) -> some View {
        content
            .glassEffect(
                isClear ? .clear : .regular,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

public extension View {
    /// Applies a rounded rectangular Liquid Glass background.
    func liquidGlassCard(cornerRadius: CGFloat = 20, isClear: Bool = false) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, isClear: isClear))
    }

    /// Applies a circular Liquid Glass background for icons and action buttons.
    func liquidGlassCircle(isClear: Bool = true) -> some View {
        self.modifier(LiquidGlassCircleModifier(isClear: isClear))
    }

    /// Applies a pill-shaped Liquid Glass background for navigation tabs and tags.
    func liquidGlassPill(isClear: Bool = false) -> some View {
        self.modifier(LiquidGlassPillModifier(isClear: isClear))
    }
}
