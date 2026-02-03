# iOS 26 Liquid Glass - Komplette Referenz & Implementation Guide

> **Stand:** Januar 2025 - WWDC 2025
> **iOS Version:** iOS 26+
> **Zweck:** Umfassende Sammlung aller Liquid Glass Effekte, Buttons und Animationen für HammerTrack

---

## 📋 Inhaltsverzeichnis

1. [Was ist Liquid Glass?](#was-ist-liquid-glass)
2. [Core APIs & Modifiers](#core-apis--modifiers)
3. [Glass Button Styles](#glass-button-styles)
4. [Morphing Animationen](#morphing-animationen)
5. [GlassEffectContainer](#glasseffectcontainer)
6. [Praktische Code-Beispiele](#praktische-code-beispiele)
7. [Best Practices](#best-practices)
8. [Performance Optimierung](#performance-optimierung)

---

## Was ist Liquid Glass?

**Liquid Glass** ist Apples neue dynamische Material-Designsprache, vorgestellt bei WWDC 2025 für iOS 26. Es kombiniert die optischen Eigenschaften von Glas mit fließender Bewegung.

### Hauptmerkmale

- **Dynamic Blur & Reflection:** Adaptiert sich dynamisch an den Hintergrund
- **Frosted Glass Effect:** Echte Unschärfe mit Farbreflektion
- **Real-time Interaction:** Reagiert auf Touch und Hover States
- **Fluid Animations:** Morphing-Effekte zwischen verwandten Elementen
- **Context-Aware:** Passt sich automatisch an Light/Dark Mode an

### Unterschied zu bisherigen Materials

| Feature | Material (iOS 15-18) | Liquid Glass (iOS 26+) |
|---------|---------------------|------------------------|
| Blur | Statisch | Dynamisch adaptiv |
| Interaktion | Keine | Touch/Hover responsive |
| Morphing | Nein | Ja (mit glassEffectID) |
| Farbreflektion | Limitiert | Vollständig |
| Animationen | Basic | Fluid & organisch |

---

## Core APIs & Modifiers

### 1. `.glassEffect()` Modifier

Der grundlegende Modifier für Liquid Glass Effekte.

```swift
// Basic Glass Effect
Text("Hello World")
    .padding()
    .glassEffect()

// Glass Effect mit custom Shape
RoundedRectangle(cornerRadius: 20)
    .fill(.white.opacity(0.2))
    .glassEffect()
    .frame(width: 300, height: 200)
```

**Parameter:**
- Keine Parameter erforderlich
- Kann auf jede View angewendet werden
- Funktioniert mit allen SwiftUI Shapes

### 2. `.glassEffect(_:in:)` - Custom Shapes

Für komplexe Shapes und custom Geometrien.

```swift
// Custom Shape mit Glass Effect
Circle()
    .glassEffect(.regular, in: .rect(cornerRadius: 20))
    .frame(width: 100, height: 100)
```

### 3. `.glassEffectID()` - Morphing Animations

Ermöglicht Morphing zwischen verwandten Views.

```swift
@State private var isExpanded = false

Button("Toggle") {
    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
        isExpanded.toggle()
    }
}
.glassEffect()
.glassEffectID("mainButton")
```

---

## Glass Button Styles

### 1. GlassButtonStyle (Official)

Apples offizieller Glass Button Style für iOS 26.

```swift
// Basic Glass Button
Button("Click Me") {
    // Action
}
.buttonStyle(.glass)

// Mit Custom Konfiguration
Button("Submit") {
    submitForm()
}
.buttonStyle(.glass)
.tint(.blue)
.controlSize(.large)
```

**Eigenschaften:**
- Automatischer Glass Border Artwork
- Context-basierte Anpassung
- Built-in Hover & Press Animationen
- Unterstützt alle ControlSize Varianten

### 2. Custom Glass Button Style

Erweiterter Custom Style mit mehr Kontrolle.

```swift
struct CustomGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(configuration.isPressed ? 0.15 : 0.1))
                    .glassEffect()
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// Usage
Button("Custom Glass") {
    // Action
}
.buttonStyle(CustomGlassButtonStyle())
```

### 3. Animated Glass Button mit Hover

```swift
struct AnimatedGlassButton: View {
    let title: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(isHovered ? 0.15 : 0.08))
                .glassEffect()
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(isHovered ? 0.4 : 0.2),
                            .white.opacity(isHovered ? 0.2 : 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(
            color: .white.opacity(isHovered ? 0.2 : 0.05),
            radius: isHovered ? 12 : 6,
            x: 0,
            y: isHovered ? 8 : 4
        )
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// Usage
AnimatedGlassButton(title: "Get Started") {
    print("Button tapped")
}
```

### 4. Glass Icon Button

```swift
struct GlassIconButton: View {
    let systemImage: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
        }
        .background(
            Circle()
                .fill(.white.opacity(isPressed ? 0.15 : 0.08))
                .glassEffect()
        )
        .overlay(
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// Usage
HStack(spacing: 16) {
    GlassIconButton(systemImage: "play.fill") { }
    GlassIconButton(systemImage: "pause.fill") { }
    GlassIconButton(systemImage: "stop.fill") { }
}
```

---

## Morphing Animationen

### Grundkonzept

Liquid Glass ermöglicht es, Views mit Glass Effect flüssig ineinander zu morphen. Dafür benötigt man:

1. **GlassEffectContainer** - Container für morphbare Views
2. **glassEffectID** - Eindeutige IDs für verwandte Views
3. **Shared Namespace** - Animation Namespace

### 1. Basic Morphing

```swift
struct BasicMorphingExample: View {
    @State private var isExpanded = false
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer {
            if isExpanded {
                // Expanded State
                RoundedRectangle(cornerRadius: 24)
                    .fill(.white.opacity(0.1))
                    .glassEffect()
                    .glassEffectID("morphShape", in: glassNamespace)
                    .frame(width: 300, height: 400)
            } else {
                // Collapsed State
                Circle()
                    .fill(.white.opacity(0.1))
                    .glassEffect()
                    .glassEffectID("morphShape", in: glassNamespace)
                    .frame(width: 80, height: 80)
            }
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }
}
```

### 2. Button Morphing Animation

```swift
struct MorphingButtonExample: View {
    @State private var selectedOption: String? = nil
    @Namespace private var buttonNamespace

    let options = ["Option 1", "Option 2", "Option 3"]

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            selectedOption = option
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedOption == option ? .white.opacity(0.2) : .white.opacity(0.08))
                            .glassEffect()
                    )
                    .glassEffectID(option, in: buttonNamespace)
                    .foregroundStyle(selectedOption == option ? .white : .white.opacity(0.7))
                }
            }
        }
    }
}
```

### 3. Expandable Card Morphing

```swift
struct ExpandableGlassCard: View {
    @State private var isExpanded = false
    @Namespace private var cardNamespace

    var body: some View {
        ZStack {
            if isExpanded {
                // Full Screen Card
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Expanded Card")
                            .font(.title)
                            .fontWeight(.bold)

                        Spacer()

                        Button(action: {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                        }
                    }

                    Text("This is the expanded content with more details and information.")
                        .font(.body)

                    Spacer()
                }
                .padding(30)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.white.opacity(0.1))
                        .glassEffect()
                        .glassEffectID("card", in: cardNamespace)
                )
                .padding(20)
            } else {
                // Compact Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tap to expand")
                        .font(.headline)

                    Text("Preview text...")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(20)
                .frame(width: 280, height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(0.1))
                        .glassEffect()
                        .glassEffectID("card", in: cardNamespace)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                }
            }
        }
    }
}
```

### 4. Tab Bar Morphing

```swift
struct MorphingTabBar: View {
    @State private var selectedTab = 0
    @Namespace private var tabNamespace

    let tabs = ["Home", "Search", "Profile"]

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedTab = index
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: getIconName(for: index))
                                .font(.system(size: 24))

                            Text(tabs[index])
                                .font(.caption)
                        }
                        .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selectedTab == index ?
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.white.opacity(0.15))
                                .glassEffect()
                                .glassEffectID("selectedTab", in: tabNamespace)
                            : nil
                        )
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.05))
                    .glassEffect()
            )
        }
    }

    private func getIconName(for index: Int) -> String {
        switch index {
        case 0: return "house.fill"
        case 1: return "magnifyingglass"
        case 2: return "person.fill"
        default: return "questionmark"
        }
    }
}
```

---

## GlassEffectContainer

### Was ist GlassEffectContainer?

`GlassEffectContainer` ist ein spezieller Container für iOS 26, der mehrere Glass Effect Views zu einer kohärenten "Glassmasse" zusammenfasst.

### Features

- **Automatic Blending:** Überlappende Shapes werden automatisch verschmolzen
- **Consistent Effects:** Einheitliche Blur- und Lichteffekte
- **Smooth Morphing:** Flüssige Übergänge bei Layout-Änderungen
- **Performance:** Optimierte Rendering für mehrere Glass Views

### Basic Usage

```swift
GlassEffectContainer {
    VStack(spacing: 20) {
        // Alle Child Views werden als eine Glassmasse behandelt
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.1))
            .glassEffect()
            .frame(height: 100)

        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.1))
            .glassEffect()
            .frame(height: 100)
    }
    .padding()
}
```

### Overlapping Glass Elements

```swift
struct OverlappingGlassExample: View {
    var body: some View {
        GlassEffectContainer {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.1))
                    .glassEffect()
                    .frame(width: 150, height: 150)
                    .offset(x: -30)

                Circle()
                    .fill(.white.opacity(0.1))
                    .glassEffect()
                    .frame(width: 150, height: 150)
                    .offset(x: 30)
            }
        }
        // Die überlappenden Bereiche verschmelzen automatisch zu einer Glassmasse
    }
}
```

### Dynamic Layout Morphing

```swift
struct DynamicLayoutMorphing: View {
    @State private var isStacked = true

    var body: some View {
        GlassEffectContainer {
            Group {
                if isStacked {
                    VStack(spacing: 16) {
                        glassCards
                    }
                } else {
                    HStack(spacing: 16) {
                        glassCards
                    }
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isStacked)
        }
        .onTapGesture {
            isStacked.toggle()
        }
    }

    @ViewBuilder
    private var glassCards: some View {
        ForEach(0..<3) { index in
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.1))
                .glassEffect()
                .frame(width: 120, height: 120)
        }
    }
}
```

---

## Praktische Code-Beispiele

### 1. Video Player Controls mit Liquid Glass

```swift
struct LiquidGlassVideoControls: View {
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    let duration: Double

    @State private var isHoveringPlay = false

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                // Timeline Slider
                VStack(spacing: 4) {
                    Slider(value: $currentTime, in: 0...duration)
                        .tint(.white)

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))

                        Spacer()

                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(0.06))
                        .glassEffect()
                )

                // Control Buttons
                HStack(spacing: 20) {
                    // Previous
                    controlButton(icon: "backward.fill") {
                        // Previous action
                    }

                    // Play/Pause
                    Button(action: { isPlaying.toggle() }) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                    }
                    .background(
                        Circle()
                            .fill(.white.opacity(isHoveringPlay ? 0.15 : 0.1))
                            .glassEffect()
                    )
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.3), lineWidth: 1.5)
                    )
                    .scaleEffect(isHoveringPlay ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringPlay)
                    .onHover { isHoveringPlay = $0 }

                    // Next
                    controlButton(icon: "forward.fill") {
                        // Next action
                    }
                }
                .padding(.vertical, 12)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.05))
                    .glassEffect()
            )
        }
    }

    private func controlButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .background(
            Circle()
                .fill(.white.opacity(0.08))
                .glassEffect()
        )
        .overlay(
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

### 2. Navigation Bar mit Liquid Glass

```swift
struct LiquidGlassNavigationBar: View {
    let title: String
    let onBack: () -> Void

    @State private var isBackPressed = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 16) {
                // Back Button
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white.opacity(isBackPressed ? 0.15 : 0.08))
                        .glassEffect()
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isBackPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isBackPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isBackPressed = true }
                        .onEnded { _ in isBackPressed = false }
                )

                // Title
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white.opacity(0.06))
                            .glassEffect()
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}
```

### 3. Settings Card mit Liquid Glass

```swift
struct LiquidGlassSettingsCard: View {
    let title: String
    let icon: String
    @Binding var isEnabled: Bool

    @State private var isHovered = false

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.1))
                            .glassEffect()
                    )

                // Title
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                // Toggle
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .tint(.blue)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isHovered ? 0.1 : 0.06))
                    .glassEffect()
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(isHovered ? 0.3 : 0.15),
                                .white.opacity(isHovered ? 0.15 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: .white.opacity(isHovered ? 0.15 : 0.05),
                radius: isHovered ? 10 : 5,
                x: 0,
                y: isHovered ? 6 : 3
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
        }
    }
}
```

### 4. Notification Badge mit Liquid Glass

```swift
struct LiquidGlassNotificationBadge: View {
    let count: Int

    @State private var isAnimating = false

    var body: some View {
        GlassEffectContainer {
            Text("\(count)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(minWidth: 20, minHeight: 20)
                .padding(.horizontal, 6)
                .background(
                    Capsule()
                        .fill(.red.opacity(0.8))
                        .glassEffect()
                )
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    .spring(response: 0.3, dampingFraction: 0.6)
                    .repeatCount(3, autoreverses: true),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
        }
    }
}
```

### 5. Floating Action Button mit Liquid Glass

```swift
struct LiquidGlassFAB: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false
    @State private var isHovered = false

    var body: some View {
        GlassEffectContainer {
            Button(action: action) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
            }
            .background(
                Circle()
                    .fill(.white.opacity(isHovered ? 0.18 : 0.12))
                    .glassEffect()
            )
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.4),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: .white.opacity(isHovered ? 0.3 : 0.15),
                radius: isHovered ? 16 : 12,
                x: 0,
                y: isHovered ? 10 : 8
            )
            .scaleEffect(isPressed ? 0.9 : (isHovered ? 1.08 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
        }
    }
}
```

---

## Best Practices

### 1. Performance

```swift
// ✅ GOOD: GlassEffectContainer für zusammenhängende Views
GlassEffectContainer {
    VStack {
        glassView1
        glassView2
        glassView3
    }
}

// ❌ BAD: Separate Containers für jede View
VStack {
    GlassEffectContainer { glassView1 }
    GlassEffectContainer { glassView2 }
    GlassEffectContainer { glassView3 }
}
```

### 2. Opacity Werte

```swift
// Empfohlene Opacity-Bereiche für Liquid Glass:

// Sehr subtil (Background Elements)
.fill(.white.opacity(0.03...0.06))

// Standard (Buttons, Cards)
.fill(.white.opacity(0.08...0.12))

// Prominent (Active States, Selected Items)
.fill(.white.opacity(0.15...0.20))

// Maximum (nie über 0.25 für Glass Effect)
.fill(.white.opacity(0.25))
```

### 3. Animation Timing

```swift
// Empfohlene Spring-Parameter für Liquid Glass:

// Schnelle Interaktionen (Button Press)
.spring(response: 0.3, dampingFraction: 0.7)

// Standard Transitions
.spring(response: 0.5, dampingFraction: 0.75)

// Morphing Animationen
.spring(response: 0.6, dampingFraction: 0.8)

// Langsame, dramatische Animationen
.spring(response: 0.8, dampingFraction: 0.85)
```

### 4. Blur Radius

```swift
// Zu hoher Blur Radius reduziert Glass-Effekt

// ✅ GOOD: Subtiler Blur
.blur(radius: 1...3)

// ⚠️ OK für spezielle Effekte
.blur(radius: 4...6)

// ❌ BAD: Zu stark, sieht nicht mehr nach Glass aus
.blur(radius: 8+)
```

### 5. Strokes & Borders

```swift
// Liquid Glass funktioniert am besten mit subtilen Strokes

// ✅ GOOD: Gradient Stroke
.stroke(
    LinearGradient(
        colors: [.white.opacity(0.3), .white.opacity(0.1)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    ),
    lineWidth: 1
)

// ✅ GOOD: Simple Stroke
.stroke(.white.opacity(0.15), lineWidth: 1)

// ❌ BAD: Zu prominent
.stroke(.white.opacity(0.8), lineWidth: 3)
```

### 6. Hintergründe

```swift
// Liquid Glass braucht kontrastreiche Hintergründe

// ✅ GOOD: Gradient Background
LinearGradient(
    colors: [.blue, .purple, .pink],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)

// ✅ GOOD: Image Background
Image("background")
    .resizable()
    .aspectRatio(contentMode: .fill)

// ⚠️ OK: Solid Color (funktioniert, aber weniger Effekt)
Color.blue

// ❌ BAD: Zu hell/Zu dunkel (kein Kontrast)
Color.white
Color.black
```

---

## Performance Optimierung

### 1. Minimize Glass Layers

```swift
// ❌ BAD: Zu viele verschachtelte Glass Layers
VStack {
    view1.glassEffect()
}
.glassEffect()
.background(
    RoundedRectangle(cornerRadius: 20)
        .glassEffect()
)

// ✅ GOOD: Nur ein Glass Layer pro View
VStack {
    view1
}
.background(
    RoundedRectangle(cornerRadius: 20)
        .fill(.white.opacity(0.1))
        .glassEffect()
)
```

### 2. Use GlassEffectContainer Strategically

```swift
// ✅ GOOD: Container für morphbare/zusammenhängende Views
GlassEffectContainer {
    HStack {
        button1.glassEffect()
        button2.glassEffect()
        button3.glassEffect()
    }
}

// ❌ BAD: Container für statische, getrennte Views
// (unnötiger Overhead wenn kein Morphing benötigt wird)
VStack {
    GlassEffectContainer { staticView1.glassEffect() }
    GlassEffectContainer { staticView2.glassEffect() }
}
```

### 3. Conditional Glass Effects

```swift
// Nur Glass Effect anwenden wenn sichtbar
struct ConditionalGlassView: View {
    @State private var isVisible = false

    var body: some View {
        content
            .if(isVisible) { view in
                view.glassEffect()
            }
    }
}

// Helper Extension
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
```

### 4. DrawingGroup für komplexe Glass Views

```swift
// Für komplexe Glass Hierarchien
GlassEffectContainer {
    ComplexGlassContent()
}
.drawingGroup() // Hardware-beschleunigtes Rendering
```

---

## Troubleshooting

### Problem: Glass Effect nicht sichtbar

**Lösung:**
```swift
// 1. Stelle sicher, dass Hintergrund kontrastreich ist
// 2. Opacity im sichtbaren Bereich (0.05-0.20)
// 3. glassEffect() nach background() aufrufen

view
    .background(.white.opacity(0.1)) // Erst Background
    .glassEffect()                   // Dann Glass Effect
```

### Problem: Morphing funktioniert nicht

**Lösung:**
```swift
// 1. GlassEffectContainer verwenden
// 2. Gleiche glassEffectID für verwandte Views
// 3. Namespace definieren und verwenden
// 4. Animation explizit definieren

@Namespace private var ns

GlassEffectContainer {
    if condition {
        view1.glassEffectID("id", in: ns)
    } else {
        view2.glassEffectID("id", in: ns)  // Gleiche ID!
    }
}
```

### Problem: Schlechte Performance

**Lösung:**
```swift
// 1. Weniger Glass Layers verwenden
// 2. drawingGroup() für komplexe Hierarchien
// 3. GlassEffectContainer sparsam einsetzen
// 4. shouldRasterize bei statischen Views

view
    .glassEffect()
    .drawingGroup()
```

---

## iOS 26 Interactive Touch Effects (WWDC 2025)

### Was ist neu in iOS 26?

iOS 26 führt **Interactive Liquid Glass** ein - eine revolutionäre Touch-Interaction-Technologie, die auf jedem Touch mit fließenden, organischen Animationen reagiert.

### Hauptmerkmale

- **Ripple Effects**: Wellenartige Ausbreitung vom Touch-Punkt
- **Interactive Glass**: `.glassEffect(.regular.interactive())`  macht Glass-Effekte touch-responsive
- **Bounce Animation**: Native Bounce bei Button-Press durch `.buttonStyle(.glass)`
- **Real-time Deformation**: Glass verformt sich wie ein Wassertropfen
- **Context-Aware Response**: Reagiert auf Lighting, Orientation und Touch-Intensität

### Interactive Glass Effect Modifier

```swift
// Basic Interactive Glass
Button("Interactive") {
    // Action
}
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(.white.opacity(0.1))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
)

// Mit Circle Shape
Button(action: { }) {
    Image(systemName: "play.fill")
        .font(.title2)
}
.frame(width: 50, height: 50)
.background(
    Circle()
        .fill(.white.opacity(0.12))
        .glassEffect(.regular.interactive(), in: .circle)
)
```

### Ripple Effect Button

Der originale iOS 26 Ripple Effect wird automatisch durch das Interactive Glass System erzeugt:

```swift
struct RippleGlassButton: View {
    let title: String
    let action: () -> Void

    @State private var isPressed = false
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0

    var body: some View {
        Button(action: {
            triggerRipple()
            action()
        }) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .background(
            ZStack {
                // Base Glass Layer
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(isPressed ? 0.15 : 0.08))
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))

                // Ripple Effect Layer
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(rippleOpacity),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100 * rippleScale
                        )
                    )
                    .scaleEffect(rippleScale)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func triggerRipple() {
        rippleOpacity = 0.4
        rippleScale = 0

        withAnimation(.easeOut(duration: 0.6)) {
            rippleScale = 1.5
            rippleOpacity = 0
        }
    }
}
```

### iOS 26 Standard Button Template

Das empfohlene Template für alle interaktiven Buttons in iOS 26:

```swift
struct iOS26GlassButton: View {
    let icon: String
    let action: () -> Void

    @State private var isPressed = false
    @State private var ripplePhase: CGFloat = 0

    var body: some View {
        Button(action: {
            triggerRipple()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .background(
            ZStack {
                // Interactive Glass Base
                Circle()
                    .fill(.white.opacity(isPressed ? 0.18 : 0.10))
                    .glassEffect(.regular.interactive(), in: .circle)

                // Ripple Animation
                Circle()
                    .stroke(Color.white.opacity(0.4 - ripplePhase * 0.4), lineWidth: 2)
                    .scaleEffect(1 + ripplePhase)
                    .opacity(1 - ripplePhase)
            }
        )
        .overlay(
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.3),
                            .white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .shadow(
            color: .black.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func triggerRipple() {
        ripplePhase = 0
        withAnimation(.easeOut(duration: 0.5)) {
            ripplePhase = 1.0
        }
    }
}
```

### Magnifying Loupe Effect (iOS 26)

Ein einzigartiger Effekt, bei dem sich Glass wie ein Wassertropfen verformt:

```swift
struct MagnifyingGlassLoupe: View {
    @State private var dragOffset: CGSize = .zero
    @State private var isDeformed = false

    var body: some View {
        Circle()
            .fill(.white.opacity(0.15))
            .glassEffect(.regular.interactive(), in: .circle)
            .frame(width: 100, height: 100)
            .scaleEffect(
                x: isDeformed ? 1.1 : 1.0,
                y: isDeformed ? 0.9 : 1.0
            )
            .offset(dragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDeformed)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        isDeformed = true
                    }
                    .onEnded { _ in
                        dragOffset = .zero
                        isDeformed = false
                    }
            )
    }
}
```

### Dynamic Glass Response System

Komplettes System für dynamische Glass-Interaktionen:

```swift
struct DynamicGlassButton: View {
    let action: () -> Void

    @State private var isPressed = false
    @State private var touchLocation: CGPoint = .zero
    @State private var rippleProgress: CGFloat = 0
    @State private var glassIntensity: Double = 0.08

    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            Button(action: {
                performAction()
            }) {
                Text("Dynamic Glass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(
                ZStack {
                    // Adaptive Glass Base
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white.opacity(glassIntensity))
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))

                    // Touch Ripple from exact touch point
                    if rippleProgress > 0 {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.3 * (1 - rippleProgress)),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                            .scaleEffect(rippleProgress * 2)
                            .position(touchLocation)
                            .allowsHitTesting(false)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isPressed ? 0.4 : 0.2),
                                .white.opacity(isPressed ? 0.2 : 0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        isPressed = true
                        touchLocation = value.location
                        glassIntensity = 0.15

                        // Start ripple from touch location
                        rippleProgress = 0
                        withAnimation(.easeOut(duration: 0.6)) {
                            rippleProgress = 1.0
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        glassIntensity = 0.08

                        // Reset ripple after animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            rippleProgress = 0
                        }
                    }
            )
        }
        .frame(height: 50)
    }

    private func performAction() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        action()
    }
}
```

### Best Practices für Interactive Touch Effects

#### 1. Immer Haptic Feedback verwenden

```swift
// ✅ GOOD: Mit Haptic Feedback
Button(action: {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    performAction()
}) { }

// ❌ BAD: Ohne Feedback
Button(action: performAction) { }
```

#### 2. Spring Animations für organisches Gefühl

```swift
// ✅ GOOD: Organische Spring Animation
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)

// ❌ BAD: Lineare Animation
.animation(.linear(duration: 0.2), value: isPressed)
```

#### 3. Interactive Glass für touch-intensive UIs

```swift
// ✅ GOOD: Interactive für Buttons und Controls
.glassEffect(.regular.interactive(), in: .circle)

// ⚠️ OK: Regular für statische Elemente
.glassEffect(.regular, in: .rect(cornerRadius: 12))
```

#### 4. Ripple Effects bei wichtigen Actions

```swift
// ✅ GOOD: Ripple für Primary Actions (Play, Submit, etc.)
primaryButton.withRippleEffect()

// ⚠️ OK: Ohne Ripple für Secondary Actions
secondaryButton.withoutRipple()
```

### Integration in bestehende Custom Modifiers

Erweiterte Version der `liquidGlassEffect` mit Interactive Support:

```swift
extension View {
    /// iOS 26 Interactive Liquid Glass Effect
    func interactiveLiquidGlass(
        style: LiquidGlassMaterialStyle = .regular,
        cornerRadius: CGFloat = 20,
        borderColor: Color = LiquidGlassColors.glassBorder,
        shape: GlassShape = .rect
    ) -> some View {
        self.background(
            ZStack {
                // Interactive Glass Base
                shapeForType(shape, cornerRadius: cornerRadius)
                    .fill(LiquidGlassColors.glassWhite)
                    .glassEffect(.regular.interactive(), in: glassShapeForType(shape, cornerRadius: cornerRadius))

                // Gradient Overlay
                shapeForType(shape, cornerRadius: cornerRadius)
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

                // Border
                shapeForType(shape, cornerRadius: cornerRadius)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
        )
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private func shapeForType(_ type: GlassShape, cornerRadius: CGFloat) -> some Shape {
        switch type {
        case .rect:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .circle:
            return AnyShape(Circle())
        case .capsule:
            return AnyShape(Capsule())
        }
    }

    private func glassShapeForType(_ type: GlassShape, cornerRadius: CGFloat) -> some InsettableShape {
        switch type {
        case .rect:
            return AnyInsettableShape(RoundedRectangle(cornerRadius: cornerRadius))
        case .circle:
            return AnyInsettableShape(Circle())
        case .capsule:
            return AnyInsettableShape(Capsule())
        }
    }
}

enum GlassShape {
    case rect, circle, capsule
}
```

---

## Zusammenfassung

### Key Takeaways

1. **`.glassEffect()`** - Grundlegender Modifier für alle Liquid Glass Effekte
2. **`.glassEffectID()`** - Für Morphing zwischen verwandten Views
3. **`GlassEffectContainer`** - Container für cohärente Glass-Massen
4. **`.buttonStyle(.glass)`** - Offizieller Glass Button Style
5. **Spring Animations** - Verwende immer Spring für organische Bewegungen

### Cheat Sheet

```swift
// Basic Glass Effect
view.glassEffect()

// Glass Button
Button("Text") { }.buttonStyle(.glass)

// Morphing Setup
@Namespace private var ns
GlassEffectContainer {
    view.glassEffectID("id", in: ns)
}

// Animation
withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
    state.toggle()
}

// Opacity Ranges
.fill(.white.opacity(0.06))  // Subtle
.fill(.white.opacity(0.12))  // Standard
.fill(.white.opacity(0.18))  // Prominent
```

---

**Dokumentiert am:** 2025-01-30
**iOS Version:** iOS 26+
**SwiftUI Version:** 6.0+
**Projekt:** HammerTrack
