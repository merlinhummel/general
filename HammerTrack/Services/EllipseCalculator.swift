//
//  EllipseCalculator.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreGraphics

/// Service for detecting and calculating ellipses from hammer trajectory data
class EllipseCalculator {

    /// Direction of movement in X-axis
    private enum Direction {
        case increasing  // Moving right
        case decreasing  // Moving left
        case unknown
    }

    /// Detects ellipses from hammer point data
    /// - Parameter hammerData: Raw hammer detection data
    /// - Returns: Array of detected ellipses
    func detectEllipses(from hammerData: HammerData) -> [Ellipse] {
        let sortedPoints = hammerData.sortedPoints

        guard sortedPoints.count >= 3 else {
            return []  // Need at least 3 points to form an ellipse
        }

        var ellipses: [Ellipse] = []
        var currentDirection: Direction = .unknown
        var reversalPoints: [HammerPoint] = [sortedPoints[0]]
        var currentEllipsePoints: [HammerPoint] = [sortedPoints[0]]

        for i in 1..<sortedPoints.count {
            let currentPoint = sortedPoints[i]
            let previousPoint = sortedPoints[i - 1]

            currentEllipsePoints.append(currentPoint)

            // Determine movement direction in X-axis
            let newDirection = getDirection(from: previousPoint.position.x, to: currentPoint.position.x)

            // Detect direction reversal
            if newDirection != currentDirection && currentDirection != .unknown && newDirection != .unknown {
                reversalPoints.append(currentPoint)

                // Complete ellipse detected (start → reversal → end)
                if reversalPoints.count == 3 {
                    let ellipse = createEllipse(
                        number: ellipses.count + 1,
                        start: reversalPoints[0],
                        reversal: reversalPoints[1],
                        end: reversalPoints[2],
                        points: currentEllipsePoints
                    )
                    ellipses.append(ellipse)

                    // Start new ellipse from current end point
                    reversalPoints = [reversalPoints[2]]
                    currentEllipsePoints = [reversalPoints[2]]
                }
            }

            if newDirection != .unknown {
                currentDirection = newDirection
            }
        }

        return ellipses
    }

    // MARK: - Private Methods

    /// Determines direction of movement
    private func getDirection(from x1: CGFloat, to x2: CGFloat) -> Direction {
        let threshold: CGFloat = 0.001  // Minimum change to detect direction

        if x2 > x1 + threshold {
            return .increasing
        } else if x2 < x1 - threshold {
            return .decreasing
        }
        return .unknown
    }

    /// Creates an ellipse from key points
    private func createEllipse(
        number: Int,
        start: HammerPoint,
        reversal: HammerPoint,
        end: HammerPoint,
        points: [HammerPoint]
    ) -> Ellipse {
        return Ellipse(
            ellipseNumber: number,
            startPoint: start,
            firstReversalPoint: reversal,
            endPoint: end,
            points: points
        )
    }
}

// MARK: - Ellipse Statistics
extension EllipseCalculator {
    /// Calculates statistics for a set of ellipses
    struct EllipseStatistics {
        let averageWidth: Double
        let averageHeight: Double
        let averageDuration: Double
        let averageTiltAngle: Double
        let consistencyScore: Double  // 0-1, higher = more consistent

        init(ellipses: [Ellipse]) {
            guard !ellipses.isEmpty else {
                self.averageWidth = 0
                self.averageHeight = 0
                self.averageDuration = 0
                self.averageTiltAngle = 0
                self.consistencyScore = 0
                return
            }

            self.averageWidth = ellipses.map { $0.width }.reduce(0, +) / Double(ellipses.count)
            self.averageHeight = ellipses.map { $0.height }.reduce(0, +) / Double(ellipses.count)
            self.averageDuration = ellipses.map { $0.duration }.reduce(0, +) / Double(ellipses.count)
            self.averageTiltAngle = ellipses.map { $0.tiltAngle }.reduce(0, +) / Double(ellipses.count)

            // Calculate consistency as inverse of coefficient of variation
            let angles = ellipses.map { $0.tiltAngle }
            let stdDev = Self.standardDeviation(angles)
            let cv = averageTiltAngle > 0 ? stdDev / averageTiltAngle : 0
            self.consistencyScore = max(0, 1 - cv)
        }

        private static func standardDeviation(_ values: [Double]) -> Double {
            guard values.count > 1 else { return 0 }
            let mean = values.reduce(0, +) / Double(values.count)
            let squaredDiffs = values.map { pow($0 - mean, 2) }
            let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)
            return sqrt(variance)
        }
    }

    /// Calculates statistics for detected ellipses
    func calculateStatistics(for ellipses: [Ellipse]) -> EllipseStatistics {
        return EllipseStatistics(ellipses: ellipses)
    }
}
