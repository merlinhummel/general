//
//  LiquidGlassButton.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// iOS 18 Liquid Glass Design button component
struct LiquidGlassButton: View {

    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false

    init(
        _ title: String,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .white.opacity(0.5), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

/// Compact icon-only glass button
struct LiquidGlassIconButton: View {

    let icon: String
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .white.opacity(0.5), radius: 2, x: -1, y: -1)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

/// Toggle button with glass effect
struct LiquidGlassToggle: View {

    let icon: String
    @Binding var isOn: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isOn ? .blue : .primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isOn ? .thinMaterial : .ultraThinMaterial)
                        .shadow(color: .white.opacity(0.5), radius: 2, x: -1, y: -1)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                )
                .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        LiquidGlassButton("Play", icon: "play.fill") {
            print("Tapped")
        }

        LiquidGlassIconButton(icon: "backward.fill") {
            print("Back")
        }

        LiquidGlassToggle(icon: "link", isOn: .constant(true)) {
            print("Toggle")
        }
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
