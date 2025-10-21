//
//  HammerData.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import CoreGraphics

/// Represents a single hammer position detected in a video frame
struct HammerPoint: Codable, Identifiable {
    let id: UUID
    let frameNumber: Int
    let timestamp: Double  // Time in seconds
    let position: CGPoint  // Normalized coordinates (0-1)
    let confidence: Float  // ML model confidence (0-1)

    init(frameNumber: Int, timestamp: Double, position: CGPoint, confidence: Float) {
        self.id = UUID()
        self.frameNumber = frameNumber
        self.timestamp = timestamp
        self.position = position
        self.confidence = confidence
    }
}

/// Collection of hammer points from ML model detection
struct HammerData: Codable {
    let videoId: UUID
    let points: [HammerPoint]
    let processingDate: Date

    init(videoId: UUID, points: [HammerPoint]) {
        self.videoId = videoId
        self.points = points
        self.processingDate = Date()
    }

    /// Returns points sorted by frame number
    var sortedPoints: [HammerPoint] {
        points.sorted { $0.frameNumber < $1.frameNumber }
    }

    /// Duration covered by the detected points
    var duration: Double {
        guard let first = points.first, let last = points.last else { return 0 }
        return last.timestamp - first.timestamp
    }

    /// Total number of frames where hammer was detected
    var totalFrames: Int {
        points.count
    }
}
