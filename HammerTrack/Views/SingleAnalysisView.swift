//
//  SingleAnalysisView.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import AVKit

/// Single video analysis view with hammer trajectory overlay
struct SingleAnalysisView: View {

    @StateObject private var viewModel: SingleAnalysisViewModel

    @Environment(\.dismiss) private var dismiss

    init(analysis: ThrowAnalysis) {
        _viewModel = StateObject(wrappedValue: SingleAnalysisViewModel(analysis: analysis))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Video player with overlay
                GeometryReader { geometry in
                    ZStack {
                        if let player = viewModel.player {
                            VideoPlayerWithOverlay(player: player) {
                                HammerPathOverlay(
                                    points: viewModel.displayPoints,
                                    highlightedEllipse: viewModel.showFullPath ? nil : viewModel.currentEllipse,
                                    showFullPath: viewModel.showFullPath
                                )
                            }
                            .gesture(
                                viewModel.showFullPath
                                    ? nil
                                    : DragGesture()
                                        .onChanged { value in
                                            viewModel.handleEllipseDrag(value: value, in: geometry)
                                        }
                            )
                            .onTapGesture {
                                viewModel.togglePathDisplay()
                            }
                        }
                    }
                }

                // Info panel
                EllipseInfoPanel(
                    ellipse: viewModel.currentEllipse,
                    totalCount: viewModel.ellipseCount
                )
                .padding(.horizontal)
                .padding(.top, 10)

                // Controls
                EllipseControl(
                    currentIndex: viewModel.currentEllipseIndex,
                    totalCount: viewModel.ellipseCount,
                    onPrevious: {
                        viewModel.previousEllipse()
                    },
                    onNext: {
                        viewModel.nextEllipse()
                    },
                    onPlay: {
                        viewModel.togglePlayback()
                    }
                )
                .padding()

                // Ellipse dot selector
                EllipseDotSelector(
                    currentIndex: viewModel.currentEllipseIndex,
                    totalCount: viewModel.ellipseCount,
                    onSelect: { index in
                        viewModel.selectEllipse(at: index)
                    }
                )
                .padding(.bottom)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Einzelanalyse")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    viewModel.togglePathDisplay()
                }) {
                    Image(systemName: viewModel.showFullPath ? "circle.fill" : "circle")
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            viewModel.seekToCurrentEllipse()
        }
    }
}

// MARK: - Preview
#Preview {
    // Mock data for preview
    let mockPoints = (0..<100).map { i in
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

    let mockData = HammerData(videoId: UUID(), points: mockPoints)

    let mockEllipses = [
        Ellipse(
            ellipseNumber: 1,
            startPoint: mockPoints[0],
            firstReversalPoint: mockPoints[15],
            endPoint: mockPoints[30],
            points: Array(mockPoints[0..<30])
        ),
        Ellipse(
            ellipseNumber: 2,
            startPoint: mockPoints[30],
            firstReversalPoint: mockPoints[45],
            endPoint: mockPoints[60],
            points: Array(mockPoints[30..<60])
        ),
    ]

    let mockMetadata = VideoMetadata(
        filename: "test.mov",
        fileURL: URL(fileURLWithPath: "/tmp/test.mov"),
        duration: 3.3,
        frameRate: 30,
        resolution: VideoResolution(width: 1920, height: 1080),
        fileSize: 1024000
    )

    let mockAnalysis = ThrowAnalysis(
        videoMetadata: mockMetadata,
        hammerData: mockData,
        ellipses: mockEllipses
    )

    NavigationStack {
        SingleAnalysisView(analysis: mockAnalysis)
    }
}
