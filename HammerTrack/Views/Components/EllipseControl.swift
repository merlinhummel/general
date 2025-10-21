//
//  EllipseControl.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Control bar for navigating ellipses
struct EllipseControl: View {

    let currentIndex: Int
    let totalCount: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onPlay: (() -> Void)?

    @State private var isPlaying = false

    init(
        currentIndex: Int,
        totalCount: Int,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPlay: (() -> Void)? = nil
    ) {
        self.currentIndex = currentIndex
        self.totalCount = totalCount
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.onPlay = onPlay
    }

    var body: some View {
        HStack(spacing: 20) {
            // Previous ellipse
            LiquidGlassIconButton(icon: "backward.fill") {
                onPrevious()
            }
            .disabled(currentIndex <= 0)
            .opacity(currentIndex <= 0 ? 0.5 : 1.0)

            // Play/Pause (optional)
            if let onPlay = onPlay {
                LiquidGlassIconButton(icon: isPlaying ? "pause.fill" : "play.fill") {
                    isPlaying.toggle()
                    onPlay()
                }
            }

            // Next ellipse
            LiquidGlassIconButton(icon: "forward.fill") {
                onNext()
            }
            .disabled(currentIndex >= totalCount - 1)
            .opacity(currentIndex >= totalCount - 1 ? 0.5 : 1.0)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10)
        )
    }
}

/// Info panel showing current ellipse information
struct EllipseInfoPanel: View {

    let ellipse: Ellipse?
    let totalCount: Int

    var body: some View {
        VStack(spacing: 8) {
            if let ellipse = ellipse {
                Text("Ellipse \(ellipse.ellipseNumber) von \(totalCount)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)

                Text(ellipse.angleDescription)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                Text(String(format: "Dauer: %.2fs", ellipse.duration))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            } else {
                Text("Keine Ellipse ausgewählt")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }
}

/// Compact ellipse selector with dots
struct EllipseDotSelector: View {

    let currentIndex: Int
    let totalCount: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalCount, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.blue : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .onTapGesture {
                        onSelect(index)
                    }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Control bar
        EllipseControl(
            currentIndex: 2,
            totalCount: 5,
            onPrevious: { print("Previous") },
            onNext: { print("Next") },
            onPlay: { print("Play") }
        )

        // Info panel
        let mockEllipse = Ellipse(
            ellipseNumber: 3,
            startPoint: HammerPoint(frameNumber: 0, timestamp: 0, position: .zero, confidence: 0.9),
            firstReversalPoint: HammerPoint(frameNumber: 10, timestamp: 0.33, position: CGPoint(x: 0, y: 0.1), confidence: 0.9),
            endPoint: HammerPoint(frameNumber: 20, timestamp: 0.66, position: .zero, confidence: 0.9),
            points: []
        )

        EllipseInfoPanel(ellipse: mockEllipse, totalCount: 5)

        // Dot selector
        EllipseDotSelector(
            currentIndex: 2,
            totalCount: 5,
            onSelect: { print("Selected \($0)") }
        )
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.gray.opacity(0.2))
}
