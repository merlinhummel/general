//
//  ComparisonView.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import AVKit

/// Comparison view for analyzing two throws side by side
struct ComparisonView: View {

    @StateObject private var viewModel: ComparisonViewModel

    @Environment(\.dismiss) private var dismiss

    init(analysis1: ThrowAnalysis, analysis2: ThrowAnalysis) {
        _viewModel = StateObject(wrappedValue: ComparisonViewModel(
            analysis1: analysis1,
            analysis2: analysis2
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    // Video 1
                    VideoSection(
                        title: "Video 1",
                        player: viewModel.player1,
                        analysis: viewModel.analysis1,
                        currentEllipse: viewModel.currentEllipse1,
                        currentIndex: viewModel.currentEllipseIndex1,
                        onPrevious: viewModel.previousEllipse1,
                        onNext: viewModel.nextEllipse1
                    )

                    // Divider with sync button
                    HStack {
                        Divider()
                            .frame(height: 2)
                            .background(Color.white.opacity(0.3))

                        LiquidGlassToggle(
                            icon: "link",
                            isOn: $viewModel.isSyncEnabled,
                            action: viewModel.toggleSync
                        )

                        Divider()
                            .frame(height: 2)
                            .background(Color.white.opacity(0.3))
                    }
                    .padding(.horizontal)

                    // Video 2
                    VideoSection(
                        title: "Video 2",
                        player: viewModel.player2,
                        analysis: viewModel.analysis2,
                        currentEllipse: viewModel.currentEllipse2,
                        currentIndex: viewModel.currentEllipseIndex2,
                        onPrevious: viewModel.previousEllipse2,
                        onNext: viewModel.nextEllipse2
                    )

                    // Comparison metrics
                    ComparisonMetricsCard(metrics: viewModel.comparisonMetrics)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Text("Vergleichsanalyse")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    if viewModel.isSyncEnabled {
                        Image(systemName: "link")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}

// MARK: - Video Section Component
struct VideoSection: View {

    let title: String
    let player: AVPlayer?
    let analysis: ThrowAnalysis
    let currentEllipse: Ellipse?
    let currentIndex: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Video player with overlay
            if let player = player {
                VideoPlayerWithOverlay(player: player) {
                    HammerPathOverlay(
                        points: analysis.hammerData.sortedPoints,
                        highlightedEllipse: currentEllipse,
                        showFullPath: false
                    )
                }
                .frame(height: 250)
                .cornerRadius(15)
                .padding(.horizontal)
            }

            // Info panel
            EllipseInfoPanel(
                ellipse: currentEllipse,
                totalCount: analysis.ellipses.count
            )
            .padding(.horizontal)

            // Controls
            EllipseControl(
                currentIndex: currentIndex,
                totalCount: analysis.ellipses.count,
                onPrevious: onPrevious,
                onNext: onNext
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Comparison Metrics Card
struct ComparisonMetricsCard: View {

    let metrics: ComparisonMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vergleichsstatistik")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                MetricRow(
                    label: "Unterschied Umdrehungen",
                    value: "\(metrics.revolutionDifference)"
                )

                MetricRow(
                    label: "Unterschied Winkel",
                    value: String(format: "%.1f°", metrics.averageAngleDifference)
                )

                MetricRow(
                    label: "Unterschied Dauer",
                    value: String(format: "%.2fs", metrics.durationDifference)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 10)
        )
    }
}

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#Preview {
    let mockPoints1 = (0..<50).map { i in
        HammerPoint(
            frameNumber: i,
            timestamp: Double(i) * 0.033,
            position: CGPoint(
                x: 0.5 + 0.3 * sin(Double(i) * 0.2),
                y: 0.5 + 0.3 * cos(Double(i) * 0.2)
            ),
            confidence: 0.9
        )
    }

    let mockData1 = HammerData(videoId: UUID(), points: mockPoints1)

    let mockEllipses1 = [
        Ellipse(
            ellipseNumber: 1,
            startPoint: mockPoints1[0],
            firstReversalPoint: mockPoints1[15],
            endPoint: mockPoints1[30],
            points: Array(mockPoints1[0..<30])
        ),
    ]

    let mockMetadata1 = VideoMetadata(
        filename: "video1.mov",
        fileURL: URL(fileURLWithPath: "/tmp/video1.mov"),
        duration: 1.65,
        frameRate: 30,
        resolution: VideoResolution(width: 1920, height: 1080),
        fileSize: 512000
    )

    let mockAnalysis1 = ThrowAnalysis(
        videoMetadata: mockMetadata1,
        hammerData: mockData1,
        ellipses: mockEllipses1
    )

    let mockAnalysis2 = ThrowAnalysis(
        videoMetadata: mockMetadata1,
        hammerData: mockData1,
        ellipses: mockEllipses1
    )

    NavigationStack {
        ComparisonView(analysis1: mockAnalysis1, analysis2: mockAnalysis2)
    }
}
