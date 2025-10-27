//
//  ComparisonViewModel.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import AVFoundation
import Combine

/// ViewModel for comparing two video analyses
@MainActor
class ComparisonViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var analysis1: ThrowAnalysis
    @Published var analysis2: ThrowAnalysis

    @Published var currentEllipseIndex1: Int = 0
    @Published var currentEllipseIndex2: Int = 0

    @Published var isSyncEnabled: Bool = false
    @Published var isPlaying: Bool = false

    @Published var currentTime1: Double = 0.0
    @Published var currentTime2: Double = 0.0

    // MARK: - Players

    var player1: AVPlayer?
    var player2: AVPlayer?

    // MARK: - Computed Properties

    var currentEllipse1: Ellipse? {
        guard currentEllipseIndex1 >= 0 && currentEllipseIndex1 < analysis1.ellipses.count else {
            return nil
        }
        return analysis1.ellipses[currentEllipseIndex1]
    }

    var currentEllipse2: Ellipse? {
        guard currentEllipseIndex2 >= 0 && currentEllipseIndex2 < analysis2.ellipses.count else {
            return nil
        }
        return analysis2.ellipses[currentEllipseIndex2]
    }

    // MARK: - Initialization

    init(analysis1: ThrowAnalysis, analysis2: ThrowAnalysis) {
        self.analysis1 = analysis1
        self.analysis2 = analysis2
        setupPlayers()
    }

    // MARK: - Player Setup

    private func setupPlayers() {
        let playerItem1 = AVPlayerItem(url: analysis1.videoMetadata.fileURL)
        player1 = AVPlayer(playerItem: playerItem1)

        let playerItem2 = AVPlayerItem(url: analysis2.videoMetadata.fileURL)
        player2 = AVPlayer(playerItem: playerItem2)
    }

    // MARK: - Synchronization

    /// Toggles synchronization mode
    func toggleSync() {
        isSyncEnabled.toggle()

        if isSyncEnabled {
            // When enabling sync, align both videos to their current positions
            syncToCurrentState()
        }
    }

    /// Syncs both videos to current state
    private func syncToCurrentState() {
        // Already in sync based on current times
    }

    // MARK: - Navigation - Video 1

    func nextEllipse1() {
        guard currentEllipseIndex1 < analysis1.ellipses.count - 1 else { return }

        if isSyncEnabled {
            // Move both forward
            currentEllipseIndex1 += 1
            currentEllipseIndex2 = min(currentEllipseIndex2 + 1, analysis2.ellipses.count - 1)
            seekToCurrentEllipses()
        } else {
            currentEllipseIndex1 += 1
            seekToEllipse1()
        }
    }

    func previousEllipse1() {
        guard currentEllipseIndex1 > 0 else { return }

        if isSyncEnabled {
            // Move both backward
            currentEllipseIndex1 -= 1
            currentEllipseIndex2 = max(currentEllipseIndex2 - 1, 0)
            seekToCurrentEllipses()
        } else {
            currentEllipseIndex1 -= 1
            seekToEllipse1()
        }
    }

    // MARK: - Navigation - Video 2

    func nextEllipse2() {
        guard currentEllipseIndex2 < analysis2.ellipses.count - 1 else { return }

        if isSyncEnabled {
            // Move both forward
            currentEllipseIndex2 += 1
            currentEllipseIndex1 = min(currentEllipseIndex1 + 1, analysis1.ellipses.count - 1)
            seekToCurrentEllipses()
        } else {
            currentEllipseIndex2 += 1
            seekToEllipse2()
        }
    }

    func previousEllipse2() {
        guard currentEllipseIndex2 > 0 else { return }

        if isSyncEnabled {
            // Move both backward
            currentEllipseIndex2 -= 1
            currentEllipseIndex1 = max(currentEllipseIndex1 - 1, 0)
            seekToCurrentEllipses()
        } else {
            currentEllipseIndex2 -= 1
            seekToEllipse2()
        }
    }

    // MARK: - Seeking

    private func seekToEllipse1() {
        guard let ellipse = currentEllipse1 else { return }
        let time = CMTime(seconds: ellipse.startPoint.timestamp, preferredTimescale: 600)
        player1?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime1 = ellipse.startPoint.timestamp
    }

    private func seekToEllipse2() {
        guard let ellipse = currentEllipse2 else { return }
        let time = CMTime(seconds: ellipse.startPoint.timestamp, preferredTimescale: 600)
        player2?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime2 = ellipse.startPoint.timestamp
    }

    private func seekToCurrentEllipses() {
        seekToEllipse1()
        seekToEllipse2()
    }

    /// Synchronized seek - maintains time offset between videos
    func synchronizedSeek(deltaTime: Double) {
        if isSyncEnabled {
            let newTime1 = currentTime1 + deltaTime
            let newTime2 = currentTime2 + deltaTime

            player1?.seek(to: CMTime(seconds: newTime1, preferredTimescale: 600))
            player2?.seek(to: CMTime(seconds: newTime2, preferredTimescale: 600))

            currentTime1 = newTime1
            currentTime2 = newTime2
        }
    }

    // MARK: - Playback Control

    func togglePlayback() {
        if isPlaying {
            player1?.pause()
            player2?.pause()
        } else {
            player1?.play()
            if isSyncEnabled {
                player2?.play()
            }
        }
        isPlaying.toggle()
    }

    // MARK: - Comparison Analytics

    /// Calculates difference metrics between the two throws
    var comparisonMetrics: ComparisonMetrics {
        ComparisonMetrics(analysis1: analysis1, analysis2: analysis2)
    }
}

// MARK: - Comparison Metrics
struct ComparisonMetrics {
    let revolutionDifference: Int
    let averageAngleDifference: Double
    let durationDifference: Double

    init(analysis1: ThrowAnalysis, analysis2: ThrowAnalysis) {
        self.revolutionDifference = abs(analysis1.revolutionCount - analysis2.revolutionCount)
        self.averageAngleDifference = abs(analysis1.averageTiltAngle - analysis2.averageTiltAngle)
        self.durationDifference = abs(analysis1.totalDuration - analysis2.totalDuration)
    }

    var formattedSummary: String {
        """
        Unterschied Umdrehungen: \(revolutionDifference)
        Unterschied Winkel: \(String(format: "%.1f°", averageAngleDifference))
        Unterschied Dauer: \(String(format: "%.2fs", durationDifference))
        """
    }
}
