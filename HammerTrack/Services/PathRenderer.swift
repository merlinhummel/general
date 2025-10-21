//
//  PathRenderer.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import CoreGraphics

/// Service for rendering hammer path overlays
class PathRenderer {

    /// Rendering options for the hammer path
    struct RenderOptions {
        var lineWidth: CGFloat = 3.0
        var lineColor: Color = .white
        var glowRadius: CGFloat = 4.0
        var glowOpacity: Double = 0.6
        var showPoints: Bool = false
        var pointRadius: CGFloat = 4.0

        static let `default` = RenderOptions()
    }

    /// Creates a CGPath from hammer points
    /// - Parameters:
    ///   - points: Array of hammer points to render
    ///   - viewSize: Size of the view to render into
    /// - Returns: CGPath representing the trajectory
    func createPath(from points: [HammerPoint], in viewSize: CGSize) -> CGPath {
        let path = CGMutablePath()

        guard !points.isEmpty else { return path }

        // Convert normalized coordinates to view coordinates
        let viewPoints = points.map { point in
            CGPoint(
                x: point.position.x * viewSize.width,
                y: point.position.y * viewSize.height
            )
        }

        // Start the path
        path.move(to: viewPoints[0])

        // Add smooth curves through all points
        if viewPoints.count == 1 {
            // Single point - just add a circle
            path.addArc(
                center: viewPoints[0],
                radius: 2,
                startAngle: 0,
                endAngle: 2 * .pi,
                clockwise: true
            )
        } else {
            // Multiple points - create smooth curve
            for i in 1..<viewPoints.count {
                path.addLine(to: viewPoints[i])
            }
        }

        return path
    }

    /// Creates a path for a single ellipse
    func createPath(from ellipse: Ellipse, in viewSize: CGSize) -> CGPath {
        createPath(from: ellipse.points, in: viewSize)
    }

    /// Creates a smooth Bézier curve through points
    /// - Parameters:
    ///   - points: Array of hammer points
    ///   - viewSize: Size of the view
    /// - Returns: Smoothed CGPath
    func createSmoothedPath(from points: [HammerPoint], in viewSize: CGSize) -> CGPath {
        let path = CGMutablePath()

        guard points.count >= 2 else {
            if let point = points.first {
                let viewPoint = CGPoint(
                    x: point.position.x * viewSize.width,
                    y: point.position.y * viewSize.height
                )
                path.addArc(
                    center: viewPoint,
                    radius: 2,
                    startAngle: 0,
                    endAngle: 2 * .pi,
                    clockwise: true
                )
            }
            return path
        }

        // Convert to view coordinates
        let viewPoints = points.map { point in
            CGPoint(
                x: point.position.x * viewSize.width,
                y: point.position.y * viewSize.height
            )
        }

        path.move(to: viewPoints[0])

        // Create smooth curve using quadratic Bézier curves
        for i in 1..<viewPoints.count {
            let currentPoint = viewPoints[i]
            let previousPoint = viewPoints[i - 1]

            // Calculate control point (midpoint)
            let controlPoint = CGPoint(
                x: (previousPoint.x + currentPoint.x) / 2,
                y: (previousPoint.y + currentPoint.y) / 2
            )

            if i == 1 {
                path.addLine(to: controlPoint)
            } else {
                path.addQuadCurve(to: controlPoint, control: previousPoint)
            }

            if i == viewPoints.count - 1 {
                path.addLine(to: currentPoint)
            }
        }

        return path
    }
}

// MARK: - SwiftUI Shape
/// SwiftUI Shape for rendering hammer path
struct HammerPathShape: Shape {
    let points: [HammerPoint]
    let smoothed: Bool

    private let renderer = PathRenderer()

    func path(in rect: CGRect) -> Path {
        let cgPath = smoothed
            ? renderer.createSmoothedPath(from: points, in: rect.size)
            : renderer.createPath(from: points, in: rect.size)
        return Path(cgPath)
    }
}

// MARK: - Ellipse Highlight Shape
/// Shape for highlighting a single ellipse
struct EllipseHighlightShape: Shape {
    let ellipse: Ellipse

    private let renderer = PathRenderer()

    func path(in rect: CGRect) -> Path {
        let cgPath = renderer.createSmoothedPath(from: ellipse.points, in: rect.size)
        return Path(cgPath)
    }
}
