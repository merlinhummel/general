import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct CompareView: View {
    @State private var showingVideoPicker = false
    @State private var selectedVideoURLs: [URL] = []
    @State private var player1: AVPlayer?
    @State private var player2: AVPlayer?
    @State private var isPlaying = false
    @State private var isSynchronized = false
    @State private var currentTime1: Double = 0
    @State private var currentTime2: Double = 0
    @State private var duration1: Double = 0
    @State private var duration2: Double = 0
    @State private var timeOffset: Double = 0 // Offset between video 2 and video 1 (currentTime2 - currentTime1)

    @StateObject private var hammerTracker1 = HammerTracker()
    @StateObject private var hammerTracker2 = HammerTracker()
    @State private var showTrajectory = true
    @State private var videoSize1: CGSize = .zero
    @State private var videoSize2: CGSize = .zero

    // Ellipsen-Navigation
    @State private var currentEllipseIndex1: Int? = nil
    @State private var currentEllipseIndex2: Int? = nil
    @State private var totalEllipses1: Int = 0
    @State private var totalEllipses2: Int = 0
    @State private var selectedEllipseIndex: Int? = nil  // Shared for both videos in sync mode
    @State private var ellipseViewMode: Bool = false  // Ellipse navigation mode active?

    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background: Fullscreen Videos
            if selectedVideoURLs.count == 2 {
                VStack(spacing: 0) {
                    // Video Player 1 (Top Half) - Fullscreen
                    if let player = player1 {
                        ZStack {
                            ZoomableVideoView(
                                player: player,
                                trajectory: showTrajectory ? hammerTracker1.currentTrajectory : nil,
                                currentTime: $currentTime1,
                                showFullTrajectory: false,
                                showTrajectory: showTrajectory,
                                selectedEllipseIndex: ellipseViewMode ? (isPlaying ? currentEllipseIndex1.map { $0 - 1 } : selectedEllipseIndex) : nil,
                                analysisResult: hammerTracker1.analysisResult
                            )
                            .background(Color.black)

                            // Processing overlay with Liquid Glass
                            if hammerTracker1.isProcessing {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Processing: \(Int(hammerTracker1.progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .floatingGlassCard(cornerRadius: 12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }

                    // Video Player 2 (Bottom Half) - Fullscreen
                    if let player = player2 {
                        ZStack {
                            ZoomableVideoView(
                                player: player,
                                trajectory: showTrajectory ? hammerTracker2.currentTrajectory : nil,
                                currentTime: $currentTime2,
                                showFullTrajectory: false,
                                showTrajectory: showTrajectory,
                                selectedEllipseIndex: ellipseViewMode ? (isPlaying ? currentEllipseIndex2.map { $0 - 1 } : selectedEllipseIndex) : nil,
                                analysisResult: hammerTracker2.analysisResult
                            )
                            .background(Color.black)

                            // Processing overlay with Liquid Glass
                            if hammerTracker2.isProcessing {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Processing: \(Int(hammerTracker2.progress * 100))%")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .padding(12)
                                .floatingGlassCard(cornerRadius: 12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    }
                }
                .ignoresSafeArea()
            } else {
                // Empty state background
                ZStack {
                    LiquidGlassBackground()

                    VStack(spacing: 20) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Wählen Sie zwei Videos zum Vergleichen")
                            .font(.headline)
                            .foregroundColor(.white)

                        Button(action: {
                            showingVideoPicker = true
                        }) {
                            Text("Videos auswählen")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .interactiveLiquidGlass(cornerRadius: 15)
                        }
                    }
                }
                .ignoresSafeArea()
            }

            // Overlay: Floating UI Elements
            VStack(spacing: 0) {
                // Floating Header Buttons (always on top)
                HStack {
                    // Back button
                    Button(action: {
                        if player1 != nil || player2 != nil {
                            // Reset players and go back to selection
                            player1 = nil
                            player2 = nil
                            selectedVideoURLs = []
                        } else {
                            // Go back to main menu
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Zurück")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)
                    }

                    Spacer()

                    // Title
                    Text("Compare View")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)

                    Spacer()

                    // Placeholder for balance
                    Color.clear
                        .frame(width: 80, height: 20)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .padding(.top, 0)

                Spacer()

                // Timeline 1 in der Mitte (am unteren Ende von Video 1)
                if selectedVideoURLs.count == 2 {
                    VStack(spacing: 4) {
                        // Ellipsen-Info für Video 1 (nur bei Sync & Ellipsen-Modus)
                        if isSynchronized && ellipseViewMode,
                           let selectedIndex = selectedEllipseIndex,
                           let analysis1 = hammerTracker1.analysisResult,
                           selectedIndex < analysis1.ellipses.count {
                            let ellipse1 = analysis1.ellipses[selectedIndex]
                            HStack(spacing: 6) {
                                Text("Ellipse \(selectedIndex + 1)/\(totalEllipses1)")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.8))
                                Text("•")
                                    .foregroundColor(.white.opacity(0.5))
                                Text(String(format: "%.1f°", abs(ellipse1.angle)))
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                Text(ellipse1.angle > 0 ? "rechts" : "links")
                                    .font(.caption2)
                                    .foregroundColor(ellipse1.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .liquidGlassEffect(style: .thin, cornerRadius: 8)
                        }

                        VStack(spacing: 2) {
                            Slider(
                                value: Binding(
                                    get: { currentTime1 },
                                    set: { newValue in
                                        currentTime1 = newValue
                                        if let player = player1 {
                                            let cmTime = CMTime(seconds: newValue, preferredTimescale: 1000)
                                            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

                                            // When synchronized, maintain the time offset
                                            if isSynchronized, let syncPlayer = player2 {
                                                let syncTime = newValue + timeOffset
                                                let clampedSyncTime = max(0, min(syncTime, duration2))
                                                syncPlayer.seek(to: CMTime(seconds: clampedSyncTime, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
                                                currentTime2 = clampedSyncTime
                                            }
                                        }
                                    }
                                ),
                                in: 0...max(duration1, 1)
                            )
                            .tint(LiquidGlassColors.accent)
                            .frame(height: 8)

                            HStack {
                                Text(formatTime(currentTime1))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                Spacer()
                                Text(formatTime(duration1))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)
                    }
                    .padding(.horizontal, 8)
                }

                Spacer()

                // Timeline 2 + Master Controls zusammen unten (direkt am unteren Rand)
                if selectedVideoURLs.count == 2 {
                    VStack(spacing: 8) {
                        // Ellipsen-Info für Video 2 + Timeline 2
                        VStack(spacing: 4) {
                            // Ellipsen-Info für Video 2 (nur bei Sync & Ellipsen-Modus)
                            if isSynchronized && ellipseViewMode,
                               let selectedIndex = selectedEllipseIndex,
                               let analysis2 = hammerTracker2.analysisResult,
                               selectedIndex < analysis2.ellipses.count {
                                let ellipse2 = analysis2.ellipses[selectedIndex]
                                HStack(spacing: 6) {
                                    Text("Ellipse \(selectedIndex + 1)/\(totalEllipses2)")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("•")
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(String(format: "%.1f°", abs(ellipse2.angle)))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                    Text(ellipse2.angle > 0 ? "rechts" : "links")
                                        .font(.caption2)
                                        .foregroundColor(ellipse2.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .liquidGlassEffect(style: .thin, cornerRadius: 8)
                            }

                            // Thin Timeline for Player 2
                            VStack(spacing: 2) {
                                Slider(
                                    value: Binding(
                                        get: { currentTime2 },
                                        set: { newValue in
                                            currentTime2 = newValue
                                            if let player = player2 {
                                                let cmTime = CMTime(seconds: newValue, preferredTimescale: 1000)
                                                player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

                                                // When synchronized, maintain the time offset
                                                if isSynchronized, let syncPlayer = player1 {
                                                    let syncTime = newValue - timeOffset
                                                    let clampedSyncTime = max(0, min(syncTime, duration1))
                                                    syncPlayer.seek(to: CMTime(seconds: clampedSyncTime, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
                                                    currentTime1 = clampedSyncTime
                                                }
                                            }
                                        }
                                    ),
                                    in: 0...max(duration2, 1)
                                )
                                .tint(LiquidGlassColors.accent)
                                .frame(height: 8)

                                HStack {
                                    Text(formatTime(currentTime2))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                    Spacer()
                                    Text(formatTime(duration2))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .liquidGlassEffect(style: .thin, cornerRadius: 12)
                        }

                        // Master Controls (erweitert bei Sync-Modus)
                        HStack(spacing: isSynchronized ? 12 : 15) {
                            // Sync button
                            Button(action: {
                                isSynchronized.toggle()
                                if isSynchronized {
                                    // When enabling sync, calculate and store the current time offset
                                    // Offset = currentTime2 - currentTime1
                                    // This offset will be maintained during synchronized playback
                                    timeOffset = currentTime2 - currentTime1
                                    print("Synchronization enabled. Time offset: \(timeOffset)s (Video1: \(currentTime1)s, Video2: \(currentTime2)s)")
                                } else {
                                    print("Synchronization disabled")
                                    ellipseViewMode = false
                                    selectedEllipseIndex = nil
                                }
                            }) {
                                Image(systemName: isSynchronized ? "link" : "link.badge.plus")
                                    .font(.system(size: 16))
                                    .foregroundColor(isSynchronized ? LiquidGlassColors.accent : .white.opacity(0.7))
                                    .frame(width: 36, height: 36)
                            }

                            // Ellipse backward (nur bei Sync sichtbar)
                            if isSynchronized {
                                Button(action: {
                                    previousEllipse()
                                }) {
                                    Image(systemName: "chevron.left.2")
                                        .font(.system(size: 16))
                                        .foregroundColor(canGoPreviousEllipse() ? .white : .white.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                }
                                .disabled(!canGoPreviousEllipse())
                            }

                            // Frame backward
                            Button(action: {
                                stepFrameBoth(forward: false)
                            }) {
                                Image(systemName: "backward.frame")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                            }

                            // Play/Pause
                            Button(action: {
                                if isPlaying {
                                    player1?.pause()
                                    player2?.pause()
                                } else {
                                    player1?.play()
                                    player2?.play()
                                }
                                isPlaying.toggle()
                            }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(LiquidGlassColors.primary)
                                    )
                                    .overlay(
                                        Circle()
                                            .stroke(LiquidGlassColors.glassBorder, lineWidth: 1.5)
                                    )
                            }

                            // Frame forward
                            Button(action: {
                                stepFrameBoth(forward: true)
                            }) {
                                Image(systemName: "forward.frame")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                            }

                            // Ellipse forward (nur bei Sync sichtbar)
                            if isSynchronized {
                                Button(action: {
                                    nextEllipse()
                                }) {
                                    Image(systemName: "chevron.right.2")
                                        .font(.system(size: 16))
                                        .foregroundColor(canGoNextEllipse() ? .white : .white.opacity(0.3))
                                        .frame(width: 36, height: 36)
                                }
                                .disabled(!canGoNextEllipse())
                            }

                            // Trajectory toggle
                            Button(action: {
                                showTrajectory.toggle()
                            }) {
                                Image(systemName: showTrajectory ? "eye" : "eye.slash")
                                    .font(.system(size: 16))
                                    .foregroundColor(showTrajectory ? LiquidGlassColors.accent : .white.opacity(0.7))
                                    .frame(width: 36, height: 36)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .liquidGlassEffect(style: .thin, cornerRadius: 16)
                        .animation(.spring(response: 0.3), value: isSynchronized)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 18)  // Gleicher Abstand wie Timeline 1 seitlich (10 + 8 = 18)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)  // VStack nimmt volle Höhe ein, Elemente oben ausgerichtet
            .ignoresSafeArea(edges: .bottom)  // Ignoriere Safe Area unten, damit 18px wirklich zum physischen Bildschirmrand sind
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVideoPicker) {
            MultipleVideoPicker(selectedVideoURLs: $selectedVideoURLs)
        }
        .onChange(of: selectedVideoURLs) { _, urls in
            if urls.count == 2 {
                setupPlayers(with: urls)
                processVideos(urls: urls)
            }
        }
    }

    private func stepFrameBoth(forward: Bool) {
        let frameRate: Double = 30
        let frameDuration = 1.0 / frameRate

        if isSynchronized {
            // When synchronized, step both players together while maintaining the offset
            // Video 1 moves by frameDuration
            let newTime1 = forward ? currentTime1 + frameDuration : currentTime1 - frameDuration
            let clampedTime1 = max(0, min(newTime1, duration1))

            // Video 2 moves by the same amount, keeping the offset
            let newTime2 = clampedTime1 + timeOffset
            let clampedTime2 = max(0, min(newTime2, duration2))

            player1?.seek(to: CMTime(seconds: clampedTime1, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            player2?.seek(to: CMTime(seconds: clampedTime2, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)

            currentTime1 = clampedTime1
            currentTime2 = clampedTime2
        } else {
            // When not synchronized, step individually
            let newTime1 = forward ? currentTime1 + frameDuration : currentTime1 - frameDuration
            let clampedTime1 = max(0, min(newTime1, duration1))
            player1?.seek(to: CMTime(seconds: clampedTime1, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime1 = clampedTime1

            let newTime2 = forward ? currentTime2 + frameDuration : currentTime2 - frameDuration
            let clampedTime2 = max(0, min(newTime2, duration2))
            player2?.seek(to: CMTime(seconds: clampedTime2, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime2 = clampedTime2
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let milliseconds = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, milliseconds)
    }

    // MARK: - Ellipsen-Navigation
    private func updateCurrentEllipseAngle() {
        // Update current ellipse for both videos
        updateCurrentEllipseForVideo(
            analysisResult: hammerTracker1.analysisResult,
            currentTime: currentTime1,
            currentIndex: &currentEllipseIndex1,
            totalEllipses: &totalEllipses1
        )

        updateCurrentEllipseForVideo(
            analysisResult: hammerTracker2.analysisResult,
            currentTime: currentTime2,
            currentIndex: &currentEllipseIndex2,
            totalEllipses: &totalEllipses2
        )
    }

    private func updateCurrentEllipseForVideo(
        analysisResult: TrajectoryAnalysis?,
        currentTime: Double,
        currentIndex: inout Int?,
        totalEllipses: inout Int
    ) {
        guard let analysis = analysisResult else {
            currentIndex = nil
            totalEllipses = 0
            return
        }

        totalEllipses = analysis.ellipses.count

        // Find the current ellipse based on current time
        for (index, ellipse) in analysis.ellipses.enumerated() {
            if let startTime = ellipse.frames.first?.timestamp,
               let endTime = ellipse.frames.last?.timestamp,
               currentTime >= startTime && currentTime <= endTime {
                currentIndex = index + 1 // 1-based indexing for display
                return
            }
        }

        currentIndex = nil
    }

    private func seekToEllipse(index: Int) {
        guard isSynchronized else { return }

        // Seek both videos to the same ellipse index
        if let analysis1 = hammerTracker1.analysisResult,
           index >= 0 && index < analysis1.ellipses.count,
           let player1 = player1 {
            let ellipse1 = analysis1.ellipses[index]
            if let startTime1 = ellipse1.frames.first?.timestamp {
                let cmTime1 = CMTime(seconds: startTime1, preferredTimescale: 1000)
                player1.seek(to: cmTime1, toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime1 = startTime1
            }
        }

        if let analysis2 = hammerTracker2.analysisResult,
           index >= 0 && index < analysis2.ellipses.count,
           let player2 = player2 {
            let ellipse2 = analysis2.ellipses[index]
            if let startTime2 = ellipse2.frames.first?.timestamp {
                let cmTime2 = CMTime(seconds: startTime2, preferredTimescale: 1000)
                player2.seek(to: cmTime2, toleranceBefore: .zero, toleranceAfter: .zero)
                currentTime2 = startTime2
            }
        }

        // Pause both videos when jumping to ellipse
        if isPlaying {
            player1?.pause()
            player2?.pause()
            isPlaying = false
        }
    }

    private func previousEllipse() {
        guard isSynchronized else { return }

        let maxEllipses = max(totalEllipses1, totalEllipses2)
        guard maxEllipses > 0 else { return }

        // Activate ellipse mode on first click
        if !ellipseViewMode {
            // Find current ellipse index based on currentTime1
            if let currentIndex = findCurrentEllipseIndex() {
                selectedEllipseIndex = currentIndex
            } else {
                selectedEllipseIndex = 0
            }
            ellipseViewMode = true
            seekToEllipse(index: selectedEllipseIndex!)
            return
        }

        // Go to previous ellipse
        if let current = selectedEllipseIndex, current > 0 {
            selectedEllipseIndex = current - 1
            seekToEllipse(index: selectedEllipseIndex!)
        }
    }

    private func nextEllipse() {
        guard isSynchronized else { return }

        let maxEllipses = max(totalEllipses1, totalEllipses2)
        guard maxEllipses > 0 else { return }

        // Activate ellipse mode on first click
        if !ellipseViewMode {
            // Find current ellipse index based on currentTime1
            if let currentIndex = findCurrentEllipseIndex() {
                selectedEllipseIndex = currentIndex
            } else {
                selectedEllipseIndex = 0
            }
            ellipseViewMode = true
            seekToEllipse(index: selectedEllipseIndex!)
            return
        }

        // Go to next ellipse
        let maxIndex = max(
            (hammerTracker1.analysisResult?.ellipses.count ?? 1) - 1,
            (hammerTracker2.analysisResult?.ellipses.count ?? 1) - 1
        )
        if let current = selectedEllipseIndex, current < maxIndex {
            selectedEllipseIndex = current + 1
            seekToEllipse(index: selectedEllipseIndex!)
        }
    }

    private func canGoPreviousEllipse() -> Bool {
        guard isSynchronized else { return false }

        let maxEllipses = max(totalEllipses1, totalEllipses2)
        guard maxEllipses > 0 else { return false }

        if !ellipseViewMode {
            return true  // First click is always possible
        }

        return selectedEllipseIndex ?? 0 > 0
    }

    private func canGoNextEllipse() -> Bool {
        guard isSynchronized else { return false }

        let maxEllipses = max(totalEllipses1, totalEllipses2)
        guard maxEllipses > 0 else { return false }

        if !ellipseViewMode {
            return true  // First click is always possible
        }

        let maxIndex = max(
            (hammerTracker1.analysisResult?.ellipses.count ?? 1) - 1,
            (hammerTracker2.analysisResult?.ellipses.count ?? 1) - 1
        )
        return (selectedEllipseIndex ?? 0) < maxIndex
    }

    private func findCurrentEllipseIndex() -> Int? {
        guard let analysis = hammerTracker1.analysisResult else { return nil }

        // Find ellipse based on currentTime1
        for (index, ellipse) in analysis.ellipses.enumerated() {
            if let startTime = ellipse.frames.first?.timestamp,
               let endTime = ellipse.frames.last?.timestamp,
               currentTime1 >= startTime && currentTime1 <= endTime {
                return index
            }
        }

        // If no ellipse found, return first
        return 0
    }

    private func setupPlayers(with urls: [URL]) {
        guard urls.count == 2 else { return }
        
        player1 = AVPlayer(url: urls[0])
        player2 = AVPlayer(url: urls[1])
        
        // Load durations and sizes
        Task {
            let asset1 = AVURLAsset(url: urls[0])
            let asset2 = AVURLAsset(url: urls[1])
            
            do {
                let duration1 = try await asset1.load(.duration)
                self.duration1 = duration1.seconds
                
                let duration2 = try await asset2.load(.duration)
                self.duration2 = duration2.seconds
                
                if let track1 = asset1.tracks(withMediaType: .video).first {
                    let size = try await track1.load(.naturalSize)
                    let transform = try await track1.load(.preferredTransform)
                    self.videoSize1 = size.applying(transform)
                }
                
                if let track2 = asset2.tracks(withMediaType: .video).first {
                    let size = try await track2.load(.naturalSize)
                    let transform = try await track2.load(.preferredTransform)
                    self.videoSize2 = size.applying(transform)
                }
            } catch {
                print("Error loading durations: \(error)")
            }
        }
        
        // Add time observers with millisecond precision
        addTimeObservers()
    }
    
    private func addTimeObservers() {
        let interval = CMTime(seconds: 0.001, preferredTimescale: 1000)

        player1?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime1 = time.seconds
            updateCurrentEllipseAngle()
        }

        player2?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            currentTime2 = time.seconds
            updateCurrentEllipseAngle()
        }
    }
    
    private func processVideos(urls: [URL]) {
        guard urls.count == 2 else { return }
        
        // Process video 1
        hammerTracker1.processVideo(url: urls[0]) { result in
            switch result {
            case .success(let trajectory):
                print("Video 1 processing complete. Detected \(trajectory.frames.count) frames")
                _ = hammerTracker1.analyzeTrajectory()
            case .failure(let error):
                print("Error processing video 1: \(error)")
            }
        }
        
        // Process video 2
        hammerTracker2.processVideo(url: urls[1]) { result in
            switch result {
            case .success(let trajectory):
                print("Video 2 processing complete. Detected \(trajectory.frames.count) frames")
                _ = hammerTracker2.analyzeTrajectory()
            case .failure(let error):
                print("Error processing video 2: \(error)")
            }
        }
    }
}

struct MultipleVideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURLs: [URL]
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 2
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultipleVideoPicker
        
        init(_ parent: MultipleVideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            var urls: [URL] = []
            let group = DispatchGroup()
            
            for result in results {
                let provider = result.itemProvider
                
                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        if let url = url {
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                            try? FileManager.default.copyItem(at: url, to: tempURL)
                            urls.append(tempURL)
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                self.parent.selectedVideoURLs = urls
            }
        }
    }
}
