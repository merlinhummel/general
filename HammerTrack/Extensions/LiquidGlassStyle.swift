import SwiftUI

// MARK: - Simple Liquid Glass Design System
// Consistent design across all views

/// Color palette for Liquid Glass design
struct LiquidGlassColors {
    static let primary = Color(red: 0.2, green: 0.4, blue: 1.0)
    static let secondary = Color(red: 0.5, green: 0.7, blue: 1.0)
    static let accent = Color(red: 0.0, green: 0.8, blue: 1.0)

    static let glassBorder = Color.white.opacity(0.25)
}

/// Material styles for Liquid Glass effect
enum LiquidGlassMaterialStyle {
    case ultra
    case regular
    case thin

    var opacity: Double {
        switch self {
        case .ultra: return 0.18
        case .regular: return 0.15
        case .thin: return 0.12
        }
    }

    var borderOpacity: (top: Double, bottom: Double) {
        switch self {
        case .ultra: return (0.4, 0.2)
        case .regular: return (0.35, 0.15)
        case .thin: return (0.3, 0.1)
        }
    }
}

// MARK: - Simple Liquid Glass Modifiers

extension View {
    /// Applies simple Liquid Glass effect with opacity + gradient border
    func liquidGlassEffect(
        style: LiquidGlassMaterialStyle = .regular,
        cornerRadius: CGFloat = 20,
        borderColor: Color = LiquidGlassColors.glassBorder
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(style.opacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(style.borderOpacity.top),
                                        Color.white.opacity(style.borderOpacity.bottom)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.white.opacity(0.12), radius: 10, x: 0, y: 5)
            )
    }

    /// Interactive liquid glass for buttons
    func interactiveLiquidGlass(
        isPressed: Bool = false,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        isPressed ?
                            LiquidGlassColors.primary.opacity(0.2) :
                            Color.white.opacity(0.15)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isPressed ? 0.5 : 0.35),
                                        Color.white.opacity(isPressed ? 0.25 : 0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: isPressed ?
                            LiquidGlassColors.primary.opacity(0.3) :
                            Color.white.opacity(0.12),
                        radius: isPressed ? 8 : 12,
                        x: 0,
                        y: isPressed ? 3 : 5
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    /// Floating glass card
    func floatingGlassCard(cornerRadius: CGFloat = 25) -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                    .shadow(color: Color.white.opacity(0.15), radius: 8, x: 0, y: -4)
            )
    }
}

// MARK: - Simple Glass Button

/// Simple glass button - consistent with all views
struct iOS26GlassButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let isDisabled: Bool

    @State private var isPressed = false

    init(icon: String, size: CGFloat = 44, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.size = size
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: {
            guard !isDisabled else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.45, weight: .medium))
                .foregroundStyle(isDisabled ? .white.opacity(0.3) : .white)
                .frame(width: size, height: size)
        }
        .disabled(isDisabled)
        .background(
            Circle()
                .fill(
                    isPressed ?
                        LiquidGlassColors.primary.opacity(0.2) :
                        Color.white.opacity(0.12)
                )
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isPressed ? 0.4 : 0.3),
                                    Color.white.opacity(isPressed ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: isPressed ?
                        LiquidGlassColors.primary.opacity(0.3) :
                        Color.white.opacity(0.12),
                    radius: isPressed ? 8 : 10,
                    x: 0,
                    y: isPressed ? 2 : 4
                )
        )
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !isDisabled else { return }
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Liquid Glass Background

struct LiquidGlassBackground: View {
    var body: some View {
        ZStack {
            // Base gradient
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

            // Atmospheric orbs
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassColors.primary.opacity(0.3),
                                    LiquidGlassColors.primary.opacity(0.15),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 250
                            )
                        )
                        .frame(width: 500, height: 500)
                        .blur(radius: 80)
                        .offset(x: -100, y: -150)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassColors.secondary.opacity(0.25),
                                    LiquidGlassColors.secondary.opacity(0.12),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 230
                            )
                        )
                        .frame(width: 450, height: 450)
                        .blur(radius: 70)
                        .offset(x: geometry.size.width - 50, y: geometry.size.height - 230)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    LiquidGlassColors.accent.opacity(0.25),
                                    LiquidGlassColors.accent.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: 400, height: 400)
                        .blur(radius: 60)
                        .offset(x: geometry.size.width * 0.5, y: geometry.size.height * 0.4)
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        Text("Simple Liquid Glass")
            .font(.title)
            .foregroundColor(.white)
            .liquidGlassEffect(style: .regular)
            .padding()

        Text("Glass Card")
            .font(.headline)
            .foregroundColor(.white)
            .floatingGlassCard()

        HStack(spacing: 25) {
            iOS26GlassButton(icon: "play.fill") {}
            iOS26GlassButton(icon: "pause.fill") {}
            iOS26GlassButton(icon: "stop.fill", size: 52) {}
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(LiquidGlassBackground())
}
