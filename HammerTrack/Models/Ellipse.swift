//
//  Ellipse.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreGraphics

/// Direction of the ellipse tilt
enum TiltDirection: String, Codable {
    case left = "left"
    case right = "right"
    case none = "none"
}

/// Represents a single ellipse (revolution) in the hammer throw
struct Ellipse: Codable, Identifiable {
    let id: UUID
    let ellipseNumber: Int  // 1-indexed position in the throw sequence

    // Key points defining the ellipse
    let startPoint: HammerPoint        // Start of the ellipse
    let firstReversalPoint: HammerPoint // First X-direction reversal
    let endPoint: HammerPoint          // End of the ellipse (= start of next)

    // All points within this ellipse
    let points: [HammerPoint]

    // Calculated properties
    let tiltAngle: Double          // Angle in degrees
    let tiltDirection: TiltDirection
    let centerPoint: CGPoint       // Calculated center of ellipse
    let width: Double              // Horizontal span
    let height: Double             // Vertical span

    init(
        ellipseNumber: Int,
        startPoint: HammerPoint,
        firstReversalPoint: HammerPoint,
        endPoint: HammerPoint,
        points: [HammerPoint]
    ) {
        self.id = UUID()
        self.ellipseNumber = ellipseNumber
        self.startPoint = startPoint
        self.firstReversalPoint = firstReversalPoint
        self.endPoint = endPoint
        self.points = points

        // Calculate tilt
        let heightDiff = firstReversalPoint.position.y - startPoint.position.y
        self.tiltDirection = heightDiff > 0 ? .right : (heightDiff < 0 ? .left : .none)

        // Calculate angle based on height difference
        // This can be calibrated based on real-world measurements
        let referenceDistance: CGFloat = 0.5  // Calibration constant
        self.tiltAngle = abs(atan(heightDiff / referenceDistance) * 180 / .pi)

        // Calculate geometric properties
        let allX = points.map { $0.position.x }
        let allY = points.map { $0.position.y }

        let minX = allX.min() ?? 0
        let maxX = allX.max() ?? 0
        let minY = allY.min() ?? 0
        let maxY = allY.max() ?? 0

        self.centerPoint = CGPoint(
            x: (minX + maxX) / 2,
            y: (minY + maxY) / 2
        )
        self.width = Double(maxX - minX)
        self.height = Double(maxY - minY)
    }

    /// Duration of this ellipse in seconds
    var duration: Double {
        endPoint.timestamp - startPoint.timestamp
    }

    /// Frame range covered by this ellipse
    var frameRange: ClosedRange<Int> {
        startPoint.frameNumber...endPoint.frameNumber
    }

    /// Formatted angle description for UI
    var angleDescription: String {
        let directionText = tiltDirection == .left ? "links" : "rechts"
        return String(format: "%.1f° %@", tiltAngle, directionText)
    }
}
