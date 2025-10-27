//
//  ThrowAnalysis.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import Foundation

/// Complete analysis of a single hammer throw
struct ThrowAnalysis: Codable, Identifiable {
    let id: UUID
    let videoMetadata: VideoMetadata
    let hammerData: HammerData
    let ellipses: [Ellipse]
    let analysisDate: Date

    init(
        videoMetadata: VideoMetadata,
        hammerData: HammerData,
        ellipses: [Ellipse]
    ) {
        self.id = UUID()
        self.videoMetadata = videoMetadata
        self.hammerData = hammerData
        self.ellipses = ellipses
        self.analysisDate = Date()
    }

    /// Total number of revolutions detected
    var revolutionCount: Int {
        ellipses.count
    }

    /// Average tilt angle across all ellipses
    var averageTiltAngle: Double {
        guard !ellipses.isEmpty else { return 0 }
        let sum = ellipses.reduce(0.0) { $0 + $1.tiltAngle }
        return sum / Double(ellipses.count)
    }

    /// Most common tilt direction
    var dominantTiltDirection: TiltDirection {
        let leftCount = ellipses.filter { $0.tiltDirection == .left }.count
        let rightCount = ellipses.filter { $0.tiltDirection == .right }.count
        return leftCount > rightCount ? .left : .right
    }

    /// Total throw duration in seconds
    var totalDuration: Double {
        hammerData.duration
    }

    /// Get ellipse at specific index (0-based)
    func ellipse(at index: Int) -> Ellipse? {
        guard index >= 0 && index < ellipses.count else { return nil }
        return ellipses[index]
    }

    /// Get ellipse containing the specified frame number
    func ellipse(containing frameNumber: Int) -> Ellipse? {
        ellipses.first { $0.frameRange.contains(frameNumber) }
    }

    /// Summary statistics for display
    var summaryText: String {
        """
        Umdrehungen: \(revolutionCount)
        Durchschn. Neigung: \(String(format: "%.1f°", averageTiltAngle))
        Hauptrichtung: \(dominantTiltDirection.rawValue)
        Dauer: \(String(format: "%.2fs", totalDuration))
        """
    }
}
