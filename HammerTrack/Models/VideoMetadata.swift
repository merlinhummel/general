//
//  VideoMetadata.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import Foundation
import AVFoundation

/// Metadata about a video being analyzed
struct VideoMetadata: Codable, Identifiable {
    let id: UUID
    let filename: String
    let fileURL: URL
    let duration: Double        // Total video duration in seconds
    let frameRate: Double       // Frames per second
    let resolution: VideoResolution
    let creationDate: Date?
    let fileSize: Int64         // Size in bytes

    init(
        filename: String,
        fileURL: URL,
        duration: Double,
        frameRate: Double,
        resolution: VideoResolution,
        creationDate: Date? = nil,
        fileSize: Int64
    ) {
        self.id = UUID()
        self.filename = filename
        self.fileURL = fileURL
        self.duration = duration
        self.frameRate = frameRate
        self.resolution = resolution
        self.creationDate = creationDate
        self.fileSize = fileSize
    }

    /// Total number of frames in video
    var totalFrames: Int {
        Int(duration * frameRate)
    }

    /// Human-readable file size
    var fileSizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Human-readable duration
    var durationDescription: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// Video resolution information
struct VideoResolution: Codable {
    let width: Int
    let height: Int

    var description: String {
        "\(width) × \(height)"
    }

    var aspectRatio: Double {
        Double(width) / Double(height)
    }
}

// MARK: - AVAsset Extension
extension VideoMetadata {
    /// Create VideoMetadata from an AVAsset
    static func from(asset: AVAsset, url: URL) async throws -> VideoMetadata {
        let duration = try await asset.load(.duration).seconds

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }

        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let naturalSize = try await videoTrack.load(.naturalSize)

        let resolution = VideoResolution(
            width: Int(naturalSize.width),
            height: Int(naturalSize.height)
        )

        // Get file attributes
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        let creationDate = attributes[.creationDate] as? Date

        return VideoMetadata(
            filename: url.lastPathComponent,
            fileURL: url,
            duration: duration,
            frameRate: Double(frameRate),
            resolution: resolution,
            creationDate: creationDate,
            fileSize: fileSize
        )
    }
}

/// Errors that can occur during video processing
enum VideoProcessingError: LocalizedError {
    case noVideoTrack
    case invalidVideoFormat
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "Video enthält keine Video-Spur"
        case .invalidVideoFormat:
            return "Ungültiges Videoformat"
        case .processingFailed(let reason):
            return "Verarbeitung fehlgeschlagen: \(reason)"
        }
    }
}
