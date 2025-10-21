//
//  SingleAnalysisViewModel.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import AVFoundation
import Combine

/// ViewModel for single video analysis view
@MainActor
class SingleAnalysisViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var analysis: ThrowAnalysis
    @Published var currentEllipseIndex: Int = 0
    @Published var showFullPath: Bool = true
    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0

    // MARK: - Player

    var player: AVPlayer?

    // MARK: - Computed Properties

    /// Currently selected ellipse
    var currentEllipse: Ellipse? {
        guard currentEllipseIndex >= 0 && currentEllipseIndex < analysis.ellipses.count else {
            return nil
        }
        return analysis.ellipses[currentEllipseIndex]
    }

    /// Points to display (either full path or just current ellipse)
    var displayPoints: [HammerPoint] {
        if showFullPath {
            return analysis.hammerData.sortedPoints
        } else if let ellipse = currentEllipse {
            return ellipse.points
        }
        return []
    }

    /// Total number of ellipses
    var ellipseCount: Int {
        analysis.ellipses.count
    }

    // MARK: - Initialization

    init(analysis: ThrowAnalysis) {
        self.analysis = analysis
        setupPlayer()
    }

    // MARK: - Player Setup

    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: analysis.videoMetadata.fileURL)
        player = AVPlayer(playerItem: playerItem)
    }

    // MARK: - Navigation

    /// Navigates to the next ellipse
    func nextEllipse() {
        guard currentEllipseIndex < ellipseCount - 1 else { return }
        currentEllipseIndex += 1
        seekToCurrentEllipse()
    }

    /// Navigates to the previous ellipse
    func previousEllipse() {
        guard currentEllipseIndex > 0 else { return }
        currentEllipseIndex -= 1
        seekToCurrentEllipse()
    }

    /// Seeks video to the start of current ellipse
    func seekToCurrentEllipse() {
        guard let ellipse = currentEllipse else { return }
        let time = CMTime(seconds: ellipse.startPoint.timestamp, preferredTimescale: 600)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = ellipse.startPoint.timestamp
    }

    // MARK: - Playback Control

    /// Toggles play/pause
    func togglePlayback() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    /// Seeks to specific time
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time

        // Update current ellipse based on time
        updateCurrentEllipse(for: time)
    }

    // MARK: - Ellipse Selection

    /// Toggles between full path and single ellipse display
    func togglePathDisplay() {
        showFullPath.toggle()
    }

    /// Selects a specific ellipse
    func selectEllipse(at index: Int) {
        guard index >= 0 && index < ellipseCount else { return }
        currentEllipseIndex = index
        showFullPath = false
        seekToCurrentEllipse()
    }

    // MARK: - Private Methods

    /// Updates current ellipse based on timestamp
    private func updateCurrentEllipse(for time: Double) {
        // Find corresponding frame number
        let points = analysis.hammerData.sortedPoints
        guard let point = points.first(where: { $0.timestamp >= time }) else { return }

        // Find ellipse containing this frame
        if let index = analysis.ellipses.firstIndex(where: { $0.frameRange.contains(point.frameNumber) }) {
            currentEllipseIndex = index
        }
    }

    // MARK: - Drag Gesture

    /// Handles drag gesture on ellipse for frame-by-frame scrubbing
    func handleEllipseDrag(value: DragGesture.Value, in geometry: GeometryProxy) {
        guard let ellipse = currentEllipse else { return }

        // Calculate progress within the ellipse based on drag position
        let progress = max(0, min(1, value.location.x / geometry.size.width))

        // Calculate time within ellipse duration
        let ellipseDuration = ellipse.duration
        let timeOffset = progress * ellipseDuration
        let targetTime = ellipse.startPoint.timestamp + timeOffset

        seek(to: targetTime)
    }
}

// MARK: - Analysis Information
extension SingleAnalysisViewModel {
    /// Formatted information about current state
    var currentInfo: String {
        guard let ellipse = currentEllipse else {
            return "Wähle eine Ellipse"
        }

        return """
        Ellipse \(ellipse.ellipseNumber) von \(ellipseCount)
        \(ellipse.angleDescription)
        """
    }

    /// Summary statistics
    var summaryStats: String {
        analysis.summaryText
    }
}
