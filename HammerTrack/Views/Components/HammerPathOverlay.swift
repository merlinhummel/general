//
//  HammerPathOverlay.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

/// Overlay view that renders the hammer trajectory path
struct HammerPathOverlay: View {

    let points: [HammerPoint]
    let highlightedEllipse: Ellipse?
    let showFullPath: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showFullPath {
                    // Full trajectory path
                    HammerPathShape(points: points, smoothed: true)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(color: .white.opacity(0.6), radius: 4)
                        .opacity(highlightedEllipse != nil ? 0.3 : 1.0)
                }

                // Highlighted ellipse (if any)
                if let ellipse = highlightedEllipse {
                    EllipseHighlightShape(ellipse: ellipse)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(
                                lineWidth: 4,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .shadow(color: .white.opacity(0.8), radius: 6)

                    // Start and end markers
                    EllipseMarkers(ellipse: ellipse, viewSize: geometry.size)
                }
            }
        }
        .allowsHitTesting(false)  // Allow touches to pass through
    }
}

/// Markers for ellipse start and end points
struct EllipseMarkers: View {

    let ellipse: Ellipse
    let viewSize: CGSize

    var body: some View {
        ZStack {
            // Start point
            Circle()
                .fill(Color.green)
                .frame(width: 12, height: 12)
                .position(
                    x: ellipse.startPoint.position.x * viewSize.width,
                    y: ellipse.startPoint.position.y * viewSize.height
                )
                .shadow(color: .green.opacity(0.8), radius: 4)

            // First reversal point
            Circle()
                .fill(Color.yellow)
                .frame(width: 12, height: 12)
                .position(
                    x: ellipse.firstReversalPoint.position.x * viewSize.width,
                    y: ellipse.firstReversalPoint.position.y * viewSize.height
                )
                .shadow(color: .yellow.opacity(0.8), radius: 4)

            // End point
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .position(
                    x: ellipse.endPoint.position.x * viewSize.width,
                    y: ellipse.endPoint.position.y * viewSize.height
                )
                .shadow(color: .red.opacity(0.8), radius: 4)
        }
    }
}

/// Simple trajectory overlay without ellipse highlighting
struct SimplePathOverlay: View {

    let points: [HammerPoint]
    let lineColor: Color
    let lineWidth: CGFloat

    init(
        points: [HammerPoint],
        lineColor: Color = .white,
        lineWidth: CGFloat = 3
    ) {
        self.points = points
        self.lineColor = lineColor
        self.lineWidth = lineWidth
    }

    var body: some View {
        HammerPathShape(points: points, smoothed: true)
            .stroke(
                lineColor,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .shadow(color: lineColor.opacity(0.6), radius: 4)
    }
}

// MARK: - Preview
#Preview {
    // Mock data for preview
    let mockPoints = [
        HammerPoint(frameNumber: 0, timestamp: 0, position: CGPoint(x: 0.3, y: 0.4), confidence: 0.9),
        HammerPoint(frameNumber: 1, timestamp: 0.033, position: CGPoint(x: 0.4, y: 0.5), confidence: 0.9),
        HammerPoint(frameNumber: 2, timestamp: 0.066, position: CGPoint(x: 0.5, y: 0.6), confidence: 0.9),
        HammerPoint(frameNumber: 3, timestamp: 0.099, position: CGPoint(x: 0.6, y: 0.5), confidence: 0.9),
        HammerPoint(frameNumber: 4, timestamp: 0.132, position: CGPoint(x: 0.5, y: 0.4), confidence: 0.9),
        HammerPoint(frameNumber: 5, timestamp: 0.165, position: CGPoint(x: 0.4, y: 0.5), confidence: 0.9),
    ]

    ZStack {
        Color.black
        HammerPathOverlay(points: mockPoints, highlightedEllipse: nil, showFullPath: true)
    }
    .frame(width: 400, height: 600)
}
