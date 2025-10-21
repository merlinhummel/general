//
//  VideoProcessingViewModel.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import AVFoundation
import Combine

/// ViewModel for handling video processing and analysis generation
@MainActor
class VideoProcessingViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isProcessing = false
    @Published var processingProgress: Double = 0.0
    @Published var currentAnalysis: ThrowAnalysis?
    @Published var error: Error?

    // MARK: - Services

    private let videoProcessor: VideoProcessor
    private let ellipseCalculator: EllipseCalculator

    // MARK: - Initialization

    init(
        videoProcessor: VideoProcessor = VideoProcessor(),
        ellipseCalculator: EllipseCalculator = EllipseCalculator()
    ) {
        self.videoProcessor = videoProcessor
        self.ellipseCalculator = ellipseCalculator
    }

    // MARK: - Public Methods

    /// Processes a video and generates complete analysis
    func processVideo(at url: URL) async {
        isProcessing = true
        processingProgress = 0.0
        error = nil

        do {
            // Step 1: Extract video metadata
            processingProgress = 0.1
            let metadata = try await VideoMetadata.from(asset: AVAsset(url: url), url: url)

            // Step 2: Process video frames and extract hammer data
            let hammerData = try await videoProcessor.processVideo(at: url) { progress in
                await MainActor.run {
                    self.processingProgress = 0.1 + (progress * 0.7)  // 10-80%
                }
            }

            // Step 3: Calculate ellipses
            processingProgress = 0.85
            let ellipses = ellipseCalculator.detectEllipses(from: hammerData)

            // Step 4: Create complete analysis
            processingProgress = 0.95
            let analysis = ThrowAnalysis(
                videoMetadata: metadata,
                hammerData: hammerData,
                ellipses: ellipses
            )

            // Complete
            currentAnalysis = analysis
            processingProgress = 1.0

        } catch {
            self.error = error
            print("Error processing video: \(error.localizedDescription)")
        }

        isProcessing = false
    }

    /// Resets the processing state
    func reset() {
        isProcessing = false
        processingProgress = 0.0
        currentAnalysis = nil
        error = nil
    }

    /// Generates thumbnail for video
    func generateThumbnail(for url: URL, at time: Double = 0) async -> CGImage? {
        do {
            return try await videoProcessor.generateThumbnail(from: url, at: time)
        } catch {
            print("Error generating thumbnail: \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Processing State
extension VideoProcessingViewModel {
    /// Current processing phase description
    var processingPhaseDescription: String {
        switch processingProgress {
        case 0..<0.1:
            return "Video laden..."
        case 0.1..<0.8:
            return "Hammer erkennen... (\(Int(processingProgress * 100))%)"
        case 0.8..<0.95:
            return "Ellipsen berechnen..."
        case 0.95...1.0:
            return "Analyse abschließen..."
        default:
            return "Verarbeite..."
        }
    }

    /// Whether an analysis is available
    var hasAnalysis: Bool {
        currentAnalysis != nil
    }
}
