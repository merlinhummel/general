//
//  VideoProcessor.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import AVFoundation
import CoreImage
import Vision

/// Service for processing video frames and extracting hammer positions
actor VideoProcessor {

    private let mlModelService: MLModelService

    init(mlModelService: MLModelService = .shared) {
        self.mlModelService = mlModelService
    }

    /// Processes a video and extracts hammer trajectory data
    /// - Parameters:
    ///   - url: URL of the video file
    ///   - progressHandler: Optional closure called with progress updates (0.0-1.0)
    /// - Returns: HammerData with detected positions
    func processVideo(
        at url: URL,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> HammerData {
        let asset = AVAsset(url: url)
        let videoId = UUID()

        // Extract frames and detect hammer
        let points = try await extractHammerPoints(
            from: asset,
            videoId: videoId,
            progressHandler: progressHandler
        )

        // Filter out low-confidence detections
        let filteredPoints = filterLowConfidencePoints(points)

        return HammerData(videoId: videoId, points: filteredPoints)
    }

    // MARK: - Private Methods

    /// Extracts hammer points from video frames
    private func extractHammerPoints(
        from asset: AVAsset,
        videoId: UUID,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> [HammerPoint] {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoProcessingError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let frameRate = try await videoTrack.load(.nominalFrameRate)
        let totalFrames = Int(duration.seconds * Double(frameRate))

        var hammerPoints: [HammerPoint] = []
        var frameNumber = 0
        var consecutiveNoDetection = 0
        let maxConsecutiveNoDetection = 5  // Stop after 5 frames without detection

        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: settings)
        reader.add(output)

        guard reader.startReading() else {
            throw VideoProcessingError.processingFailed("Failed to start reading video")
        }

        while let sampleBuffer = output.copyNextSampleBuffer() {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

            // Detect hammer in this frame
            if let detection = await mlModelService.detectHammer(in: pixelBuffer) {
                let point = HammerPoint(
                    frameNumber: frameNumber,
                    timestamp: timestamp,
                    position: detection.position,
                    confidence: detection.confidence
                )
                hammerPoints.append(point)
                consecutiveNoDetection = 0
            } else {
                consecutiveNoDetection += 1

                // Stop processing if hammer hasn't been detected for too long
                if consecutiveNoDetection >= maxConsecutiveNoDetection && !hammerPoints.isEmpty {
                    break
                }
            }

            frameNumber += 1

            // Report progress
            let progress = Double(frameNumber) / Double(totalFrames)
            await progressHandler?(min(progress, 1.0))
        }

        reader.cancelReading()

        return hammerPoints
    }

    /// Filters out points with low confidence
    private func filterLowConfidencePoints(_ points: [HammerPoint]) -> [HammerPoint] {
        let confidenceThreshold: Float = 0.5
        return points.filter { $0.confidence >= confidenceThreshold }
    }

    /// Creates a thumbnail image from video at specific time
    func generateThumbnail(
        from url: URL,
        at time: Double
    ) async throws -> CGImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero

        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        let (image, _) = try await imageGenerator.image(at: cmTime)

        return image
    }
}
