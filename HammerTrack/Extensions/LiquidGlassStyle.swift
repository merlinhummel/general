import SwiftUI

// MARK: - iOS 26 Liquid Glass Design System
// Based on Apple's WWDC 2025 Liquid Glass Guidelines

/// Color palette for Liquid Glass design
struct LiquidGlassColors {
    static let primary = Color(red: 0.2, green: 0.4, blue: 1.0)
    static let secondary = Color(red: 0.5, green: 0.7, blue: 1.0)
    static let accent = Color(red: 0.0, green: 0.8, blue: 1.0)

    // 30% more transparent for better video visibility
    static let glassWhite = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.12)
    static let glassHighlight = Color.white.opacity(0.4)
}

/// Material styles for Liquid Glass effect
enum LiquidGlassMaterialStyle {
    case ultra
    case regular
    case thin

    var blurRadius: CGFloat {
        switch self {
        case .ultra: return 14  // 30% less blur
        case .regular: return 10 // 30% less blur
        case .thin: return 7     // 30% less blur
        }
    }

    var opacity: Double {
        switch self {
        case .ultra: return 0.10  // 30% more transparent
        case .regular: return 0.07 // 30% more transparent
        case .thin: return 0.03    // 30% more transparent
        }
    }
}

// MARK: - Liquid Glass Modifiers

extension View {
    /// Applies iOS 26 Liquid Glass effect to the view
    /// - Parameters:
    ///   - style: The material style (ultra, regular, thin)
    ///   - cornerRadius: Corner radius for the glass effect
    ///   - borderColor: Optional border color
    func liquidGlassEffect(
        style: LiquidGlassMaterialStyle = .regular,
        cornerRadius: CGFloat = 20,
        borderColor: Color = LiquidGlassColors.glassBorder
    ) -> some View {
        self
            .background(
                ZStack {
                    // Base glass layer with blur
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(LiquidGlassColors.glassWhite)
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: cornerRadius)
                        )

                    // Gradient overlay for depth (more transparent)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Border with glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    /// Applies interactive liquid glass effect with hover/press states
    func interactiveLiquidGlass(
        isPressed: Bool = false,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self
            .background(
                ZStack {
                    // Dynamic background that responds to interaction
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: isPressed ? [
                                    LiquidGlassColors.primary.opacity(0.2),
                                    LiquidGlassColors.secondary.opacity(0.12)
                                ] : [
                                    LiquidGlassColors.primary.opacity(0.12),
                                    LiquidGlassColors.secondary.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            .ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: cornerRadius)
                        )

                    // Highlight effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassColors.glassHighlight,
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            isPressed ?
                                LiquidGlassColors.accent.opacity(0.4) :
                                LiquidGlassColors.glassBorder,
                            lineWidth: 1.5
                        )
                }
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: isPressed ?
                    LiquidGlassColors.primary.opacity(0.3) :
                    Color.black.opacity(0.1),
                radius: isPressed ? 15 : 10,
                x: 0,
                y: isPressed ? 3 : 5
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    /// Applies floating glass card effect
    func floatingGlassCard(cornerRadius: CGFloat = 25) -> some View {
        self
            .padding()
            .background(
                ZStack {
                    // Main glass surface
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Depth gradient (more transparent)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.03),
                                    Color.black.opacity(0.01)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Refraction effect at edges (more transparent)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
            .shadow(color: Color.white.opacity(0.1), radius: 1, x: 0, y: -1)
    }
}

// MARK: - Liquid Glass Background

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            // Base gradient - static, no animation
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.15, blue: 0.3),
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating orbs for depth
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassColors.primary.opacity(0.3),
                                    LiquidGlassColors.primary.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(x: -100, y: -150)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassColors.secondary.opacity(0.25),
                                    LiquidGlassColors.secondary.opacity(0.08),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 350, height: 350)
                        .blur(radius: 50)
                        .offset(x: geometry.size.width - 100, y: geometry.size.height - 200)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        Text("Liquid Glass Preview")
            .font(.title)
            .foregroundColor(.white)
            .liquidGlassEffect()
            .padding()

        Text("Floating Card")
            .font(.headline)
            .foregroundColor(.white)
            .floatingGlassCard()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LiquidGlassBackground())
}
