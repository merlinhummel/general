//
//  VideoPlayerView.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import AVFoundation
import AVKit

/// Video player view with AVPlayer integration
struct VideoPlayerView: View {

    let player: AVPlayer
    let showControls: Bool

    init(player: AVPlayer, showControls: Bool = false) {
        self.player = player
        self.showControls = showControls
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video layer
                VideoPlayer(player: player) {
                    // Custom overlay can go here if needed
                }
                .disabled(!showControls)  // Disable default controls if needed
            }
        }
        .background(Color.black)
    }
}

/// Custom video player with manual controls
struct CustomVideoPlayerView: UIViewRepresentable {

    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = view.bounds

        view.layer.addSublayer(playerLayer)
        context.coordinator.playerLayer = playerLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let playerLayer = context.coordinator.playerLayer {
            playerLayer.frame = uiView.bounds
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var playerLayer: AVPlayerLayer?
    }
}

/// Video player with overlay support
struct VideoPlayerWithOverlay<Overlay: View>: View {

    let player: AVPlayer
    @ViewBuilder let overlay: () -> Overlay

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Video player
                CustomVideoPlayerView(player: player)

                // Overlay content
                overlay()
            }
        }
        .background(Color.black)
    }
}

// MARK: - Preview
#Preview {
    if let url = Bundle.main.url(forResource: "sample", withExtension: "mp4") {
        VideoPlayerView(player: AVPlayer(url: url), showControls: true)
    } else {
        Text("No sample video")
    }
}
