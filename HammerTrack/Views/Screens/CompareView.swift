import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers
import Combine

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
    @State private var isLoadingVideos = false  // Video-Lade-Animation
    @State private var rotationAngle: Double = 0  // Zahnrad-Rotation

    // Playback Speed für beide Videos
    @State private var playbackSpeed1: Float = 1.0
    @State private var playbackSpeed2: Float = 1.0
    @State private var hasTriggeredSwipe1 = false
    @State private var hasTriggeredSwipe2 = false

    // Combine cancellables for player status observation
    @State private var cancellables = Set<AnyCancellable>()

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

                            // Processing overlay zentriert
                            if hammerTracker1.isProcessing {
                                VStack {
                                    Spacer()

                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .tint(.white)

                                        Text("Analysiere Video...")
                                            .font(.subheadline)
                                            .foregroundColor(.white)

                                        ProgressView(value: hammerTracker1.progress)
                                            .frame(width: 150)
                                            .tint(LiquidGlassColors.accent)

                                        Text("\(Int(hammerTracker1.progress * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                    .padding(20)
                                    .floatingGlassCard(cornerRadius: 16)

                                    Spacer()
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea(edges: .top)  // Nutze vollen Bereich bis zur Dynamic Island
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

                            // Processing overlay zentriert
                            if hammerTracker2.isProcessing {
                                VStack {
                                    Spacer()

                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                            .tint(.white)

                                        Text("Analysiere Video...")
                                            .font(.subheadline)
                                            .foregroundColor(.white)

                                        ProgressView(value: hammerTracker2.progress)
                                            .frame(width: 150)
                                            .tint(LiquidGlassColors.accent)

                                        Text("\(Int(hammerTracker2.progress * 100))%")
                                            .font(.caption2)
                                            .foregroundColor(.white)
                                    }
                                    .padding(20)
                                    .floatingGlassCard(cornerRadius: 16)

                                    Spacer()
                                }
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea(edges: .bottom)  // Nutze vollen Bereich bis zum unteren Bildschirmrand
                    }
                }
                .ignoresSafeArea()
            } else {
                // Empty state background
                ZStack {
                    LiquidGlassBackground()

                    VStack(spacing: 20) {
                        // Rotierendes Zahnrad beim Laden, sonst normales Icon
                        ZStack {
                            if isLoadingVideos {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.8))
                                    .rotationEffect(.degrees(rotationAngle))
                                    .onAppear {
                                        // Starte endlose Rotation
                                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                                            rotationAngle = 360
                                        }
                                    }
                            } else {
                                Image(systemName: "rectangle.stack")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        Text(isLoadingVideos ? "Videos werden geladen..." : "Wählen Sie zwei Videos zum Vergleichen")
                            .font(.headline)
                            .foregroundColor(.white)

                        if !isLoadingVideos {
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
                    .onChange(of: isLoadingVideos) { _, loading in
                        if loading {
                            rotationAngle = 0  // Reset rotation
                        }
                    }
                }
                .ignoresSafeArea()
            }

            // Overlay: Floating UI Elements
            VStack(spacing: 0) {
                // Floating Header Buttons (always on top) - gleiche Abstände wie Single View
                HStack {
                    // Back button - gleiche Breite wie Zeitmodi für perfekte Titel-Zentrierung
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
                        .frame(width: 100)
                    }
                    .interactiveLiquidGlass(cornerRadius: 12)

                    Spacer()

                    // Title - Liquid Glass Style (in der Mitte)
                    Text("Compare View")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)

                    Spacer()

                    // Zeitmodi Button - EXAKT wie Zurück Button, nur auf rechter Seite
                    DualSpeedControl(
                        speed1: $playbackSpeed1,
                        speed2: $playbackSpeed2,
                        hasTriggeredSwipe1: $hasTriggeredSwipe1,
                        hasTriggeredSwipe2: $hasTriggeredSwipe2,
                        isPlaying: isPlaying,
                        player1: player1,
                        player2: player2
                    )
                }
                .padding(.horizontal, 20)  // Gleicher Abstand zum Bildschirmrand wie Single View (20px)
                .padding(.vertical, 12)
                .padding(.top, 0)

                Spacer()

                // Video Player 1 Timeline - Liquid Glass Style
                if selectedVideoURLs.count == 2 {
                    ZStack(alignment: .top) {
                        VStack(spacing: 4) {
                            // Timeline - dünner Slider
                            Slider(
                                value: Binding(
                                    get: { currentTime1 },
                                    set: { newValue in
                                        currentTime1 = newValue
                                        let cmTime = CMTime(seconds: newValue, preferredTimescale: 1000)
                                        player1?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

                                        // When synchronized, maintain the time offset
                                        if isSynchronized {
                                            let syncTime = newValue + timeOffset
                                            let clampedSyncTime = max(0, min(syncTime, duration2))
                                            player2?.seek(to: CMTime(seconds: clampedSyncTime, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
                                            currentTime2 = clampedSyncTime
                                        }
                                    }
                                ),
                                in: 0...max(duration1, 1)
                            )
                            .tint(LiquidGlassColors.accent)
                            .frame(height: 8)

                            // Time labels - jede Hälfte zentriert
                            HStack(spacing: 0) {
                                // Linke Hälfte: currentTime zentriert
                                Text(formatTime(currentTime1))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .center)

                                // Rechte Hälfte: duration zentriert
                                Text(formatTime(duration1))
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.25),
                                                    Color.white.opacity(0.08)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color.white.opacity(0.08), radius: 6, x: 0, y: 3)
                        )
                        .frame(maxWidth: 500)
                        .padding(.horizontal, 20)
                        .offset(y: -15)

                        // Info-Box für oberen Player (Player 1) - schwebt über Timeline (gleicher Abstand wie unten)
                        if isSynchronized && ellipseViewMode,
                           let selectedIndex = selectedEllipseIndex,
                           let analysis1 = hammerTracker1.analysisResult,
                           selectedIndex < analysis1.ellipses.count {
                            let ellipse1 = analysis1.ellipses[selectedIndex]
                            VStack(spacing: 1) {
                                Text("Ellipse \(selectedIndex + 1)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white.opacity(0.8))

                                HStack(spacing: 3) {
                                    Image(systemName: ellipse1.angle > 0 ? "arrow.up.right" : "arrow.up.left")
                                        .font(.system(size: 9))
                                        .foregroundColor(ellipse1.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)

                                    Text(String(format: "%.1f°", abs(ellipse1.angle)))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)

                                    Text(ellipse1.angle > 0 ? "rechts" : "links")
                                        .font(.system(size: 9))
                                        .foregroundColor(ellipse1.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.4),
                                                        Color.white.opacity(0.15)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1
                                            )
                                    )
                                    .shadow(color: LiquidGlassColors.accent.opacity(0.2), radius: 8, x: 0, y: 2)
                            )
                            .offset(y: -50)
                        }
                    }
                }

                Spacer()

                // Info-Box für unteren Player (Player 2) - an der oberen Kante der Control-Bar
                if selectedVideoURLs.count == 2,
                   isSynchronized && ellipseViewMode,
                   let selectedIndex = selectedEllipseIndex,
                   let analysis2 = hammerTracker2.analysisResult,
                   selectedIndex < analysis2.ellipses.count {
                    let ellipse2 = analysis2.ellipses[selectedIndex]

                    VStack(spacing: 1) {
                        Text("Ellipse \(selectedIndex + 1)")
                            .font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 3) {
                            Image(systemName: ellipse2.angle > 0 ? "arrow.up.right" : "arrow.up.left")
                                .font(.system(size: 9))
                                .foregroundColor(ellipse2.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)

                            Text(String(format: "%.1f°", abs(ellipse2.angle)))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)

                            Text(ellipse2.angle > 0 ? "rechts" : "links")
                                .font(.system(size: 9))
                                .foregroundColor(ellipse2.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                            .shadow(color: LiquidGlassColors.accent.opacity(0.2), radius: 8, x: 0, y: 2)
                    )
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                    .allowsHitTesting(false)
                }

                // Video Player 2 Controls (am unteren Ende von Video 2)
                if selectedVideoURLs.count == 2, let player1 = player1, let player2 = player2 {
                    CompareVideoControls(
                        player: player2,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime2,
                        duration: $duration2,
                        showTrajectory: $showTrajectory,
                        currentEllipseIndex: currentEllipseIndex2,
                        totalEllipses: totalEllipses2,
                        selectedEllipseIndex: $selectedEllipseIndex,
                        ellipseViewMode: $ellipseViewMode,
                        analysisResult1: hammerTracker1.analysisResult,
                        analysisResult2: hammerTracker2.analysisResult,
                        isSynchronized: isSynchronized,
                        isPlayer2: true,
                        otherPlayer: player1,
                        otherCurrentTime: $currentTime1,
                        otherDuration: duration1,
                        timeOffset: $timeOffset,
                        onSyncToggle: {
                            isSynchronized.toggle()
                            if isSynchronized {
                                timeOffset = currentTime2 - currentTime1
                                print("Synchronization enabled. Time offset: \(timeOffset)s")
                            } else {
                                print("Synchronization disabled")
                                ellipseViewMode = false
                                selectedEllipseIndex = nil
                            }
                        },
                        onEllipseChange: { seekToEllipse(index: $0) },
                        onFrameStep: { forward in stepFrameBoth(forward: forward) },
                        onPreviousEllipse: previousEllipse,
                        onNextEllipse: nextEllipse,
                        canGoPreviousEllipse: canGoPreviousEllipse,
                        canGoNextEllipse: canGoNextEllipse
                    )
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)  // VStack nimmt volle Höhe ein, Elemente oben ausgerichtet
            .ignoresSafeArea(edges: .bottom)  // Ignoriere Safe Area unten, damit 18px wirklich zum physischen Bildschirmrand sind
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVideoPicker, onDismiss: {
            // Wenn Picker geschlossen wird, starte Loading-Animation
            // (bevor Videos fertig kopiert sind)
            if !selectedVideoURLs.isEmpty || showingVideoPicker == false {
                isLoadingVideos = true
            }
        }) {
            MultipleVideoPicker(selectedVideoURLs: $selectedVideoURLs, isLoadingVideos: $isLoadingVideos)
        }
        .onChange(of: selectedVideoURLs) { _, urls in
            if urls.count == 2 {
                // Reset analysis state
                hammerTracker1.currentTrajectory = nil
                hammerTracker1.analysisResult = nil
                hammerTracker2.currentTrajectory = nil
                hammerTracker2.analysisResult = nil

                // Reset playback state
                currentTime1 = 0
                currentTime2 = 0
                isPlaying = false
                isSynchronized = false
                ellipseViewMode = false
                selectedEllipseIndex = nil

                setupPlayers(with: urls)
                processVideos(urls: urls)
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                // Apply playback speeds when starting (don't reset them!)
                player1?.play()
                player2?.play()
                player1?.rate = playbackSpeed1
                player2?.rate = playbackSpeed2
            } else {
                player1?.pause()
                player2?.pause()
            }
        }
        .onChange(of: playbackSpeed1) { _, newSpeed in
            // Update speed ONLY if currently playing (don't auto-start!)
            if isPlaying {
                player1?.rate = newSpeed
                print("⚡ Video 1 speed changed to \(newSpeed)x while playing")
            } else {
                print("⚡ Video 1 speed stored as \(newSpeed)x (will apply on play)")
            }
        }
        .onChange(of: playbackSpeed2) { _, newSpeed in
            // Update speed ONLY if currently playing (don't auto-start!)
            if isPlaying {
                player2?.rate = newSpeed
                print("⚡ Video 2 speed changed to \(newSpeed)x while playing")
            } else {
                print("⚡ Video 2 speed stored as \(newSpeed)x (will apply on play)")
            }
        }
        .onAppear {
            // Reset playback speeds to 1.0x when view appears
            playbackSpeed1 = 1.0
            playbackSpeed2 = 1.0
            print("🔄 CompareView appeared - playback speeds reset to 1.0x")
        }
        .onDisappear {
            // Reset playback speeds when leaving the view
            playbackSpeed1 = 1.0
            playbackSpeed2 = 1.0
            print("🔄 CompareView dismissed - playback speeds reset to 1.0x")
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
        let maxEllipses = max(totalEllipses1, totalEllipses2)
        guard maxEllipses > 0 else { return false }

        if !ellipseViewMode {
            return true  // First click is always possible
        }

        return selectedEllipseIndex ?? 0 > 0
    }

    private func canGoNextEllipse() -> Bool {
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

        print("🎬 Setting up players:")
        print("   Video 1: \(urls[0].lastPathComponent)")
        print("   Video 2: \(urls[1].lastPathComponent)")

        // Create player items with status observation
        let asset1 = AVURLAsset(url: urls[0])
        let playerItem1 = AVPlayerItem(asset: asset1)

        let asset2 = AVURLAsset(url: urls[1])
        let playerItem2 = AVPlayerItem(asset: asset2)

        // Observe player 1 status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem1,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Video 1 failed to play: \(error.localizedDescription)")
            }
        }

        playerItem1.publisher(for: \.status)
            .sink { status in
                switch status {
                case .readyToPlay:
                    print("✅ Player 1 ready: \(urls[0].lastPathComponent)")
                case .failed:
                    print("❌ Player 1 failed: \(playerItem1.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    print("⚠️ Player 1 status unknown")
                @unknown default:
                    print("⚠️ Player 1 status: \(status)")
                }
            }
            .store(in: &cancellables)

        // Observe player 2 status
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem2,
            queue: .main
        ) { notification in
            if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                print("❌ Video 2 failed to play: \(error.localizedDescription)")
            }
        }

        playerItem2.publisher(for: \.status)
            .sink { status in
                switch status {
                case .readyToPlay:
                    print("✅ Player 2 ready: \(urls[1].lastPathComponent)")
                case .failed:
                    print("❌ Player 2 failed: \(playerItem2.error?.localizedDescription ?? "Unknown error")")
                case .unknown:
                    print("⚠️ Player 2 status unknown")
                @unknown default:
                    print("⚠️ Player 2 status: \(status)")
                }
            }
            .store(in: &cancellables)

        player1 = AVPlayer(playerItem: playerItem1)
        player2 = AVPlayer(playerItem: playerItem2)

        // ⚡️ OPTIMIERUNG: Parallel Asset-Loading (2x schneller)
        Task {
            do {
                // Load both assets in parallel using async let
                async let duration1Task = asset1.load(.duration)
                async let duration2Task = asset2.load(.duration)

                let (duration1, duration2) = try await (duration1Task, duration2Task)
                self.duration1 = duration1.seconds
                self.duration2 = duration2.seconds
                print("⏱️ Video 1 duration: \(duration1.seconds)s")
                print("⏱️ Video 2 duration: \(duration2.seconds)s")

                // Load video tracks in parallel
                async let track1Task = asset1.tracks(withMediaType: .video).first
                async let track2Task = asset2.tracks(withMediaType: .video).first

                let (track1, track2) = await (track1Task, track2Task)

                // Load track properties in parallel
                if let track1 = track1 {
                    async let sizeTask = track1.load(.naturalSize)
                    async let transformTask = track1.load(.preferredTransform)
                    let (size, transform) = try await (sizeTask, transformTask)
                    self.videoSize1 = size.applying(transform)
                    print("📐 Video 1 size: \(self.videoSize1)")
                } else {
                    print("⚠️ Video 1: No video track found!")
                }

                if let track2 = track2 {
                    async let sizeTask = track2.load(.naturalSize)
                    async let transformTask = track2.load(.preferredTransform)
                    let (size, transform) = try await (sizeTask, transformTask)
                    self.videoSize2 = size.applying(transform)
                    print("📐 Video 2 size: \(self.videoSize2)")
                } else {
                    print("⚠️ Video 2: No video track found!")
                }

                // Loading fertig - Animation ausblenden
                await MainActor.run {
                    self.isLoadingVideos = false
                }
                print("✅ Both videos loaded successfully")
            } catch {
                print("❌ Error loading durations: \(error)")
                await MainActor.run {
                    self.isLoadingVideos = false
                }
            }
        }

        // Add time observers with millisecond precision
        addTimeObservers()
    }
    
    private func addTimeObservers() {
        let interval = CMTime(seconds: 0.001, preferredTimescale: 1000)

        player1?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            currentTime1 = time.seconds

            // Check if video 1 reached the end
            if currentTime1 >= duration1 - 0.1 && isPlaying {
                DispatchQueue.main.async {
                    player1?.seek(to: .zero)
                    isPlaying = false
                    print("🔄 Video 1 ended - showing Play button")
                }
            }

            updateCurrentEllipseAngle()
        }

        player2?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            currentTime2 = time.seconds

            // Check if video 2 reached the end
            if currentTime2 >= duration2 - 0.1 && isPlaying {
                DispatchQueue.main.async {
                    player2?.seek(to: .zero)
                    isPlaying = false
                    print("🔄 Video 2 ended - showing Play button")
                }
            }

            updateCurrentEllipseAngle()
        }
    }
    
    private func processVideos(urls: [URL]) {
        guard urls.count == 2 else { return }

        // ⚡️ OPTIMIERUNG: Parallel Video Processing (2x schneller)
        // Process both videos simultaneously
        DispatchQueue.global(qos: .userInitiated).async {
            self.hammerTracker1.processVideo(url: urls[0]) { result in
                switch result {
                case .success(let trajectory):
                    print("Video 1 processing complete. Detected \(trajectory.frames.count) frames")
                    _ = self.hammerTracker1.analyzeTrajectory()
                case .failure(let error):
                    print("Error processing video 1: \(error)")
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            self.hammerTracker2.processVideo(url: urls[1]) { result in
                switch result {
                case .success(let trajectory):
                    print("Video 2 processing complete. Detected \(trajectory.frames.count) frames")
                    _ = self.hammerTracker2.analyzeTrajectory()
                case .failure(let error):
                    print("Error processing video 2: \(error)")
                }
            }
        }
    }
}

struct MultipleVideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURLs: [URL]
    @Binding var isLoadingVideos: Bool
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
            // Wenn Videos ausgewählt wurden, aktiviere Loading sofort
            if !results.isEmpty {
                parent.isLoadingVideos = true
            }

            parent.presentationMode.wrappedValue.dismiss()

            // ⚡️ OPTIMIERUNG: loadFileRepresentation läuft bereits parallel für jedes Video
            let urlsQueue = DispatchQueue(label: "com.hammertrack.urls")
            var urls: [URL] = []
            let group = DispatchGroup()

            for result in results {
                let provider = result.itemProvider

                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    group.enter()
                    // Wichtig: Kopieren muss INNERHALB des loadFileRepresentation-Closures passieren,
                    // da die URL nur temporär ist und danach gelöscht wird
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                        if let url = url {
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                            do {
                                // Falls Datei existiert, erst löschen
                                try? FileManager.default.removeItem(at: tempURL)
                                // Kopieren im selben Thread - die URL ist nur hier gültig!
                                try FileManager.default.copyItem(at: url, to: tempURL)

                                // Thread-safe URL hinzufügen (synchron, damit URLs verfügbar sind vor group.notify)
                                urlsQueue.sync {
                                    urls.append(tempURL)
                                }
                            } catch {
                                print("❌ Error copying video file: \(error)")
                            }
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                print("✅ Videos loaded: \(urls.count) files")
                if urls.isEmpty {
                    // Keine Videos ausgewählt → Loading stoppen
                    self.parent.isLoadingVideos = false
                }
                self.parent.selectedVideoURLs = urls
            }
        }
    }
}

// MARK: - Compare Video Controls View
struct CompareVideoControls: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var showTrajectory: Bool
    let currentEllipseIndex: Int?
    let totalEllipses: Int
    @Binding var selectedEllipseIndex: Int?
    @Binding var ellipseViewMode: Bool
    let analysisResult1: TrajectoryAnalysis?  // Oberer Player (Player 1)
    let analysisResult2: TrajectoryAnalysis?  // Unterer Player (Player 2)

    // Compare-specific properties
    let isSynchronized: Bool
    let isPlayer2: Bool  // Player 2 hat den Sync-Button
    let otherPlayer: AVPlayer?
    @Binding var otherCurrentTime: Double
    let otherDuration: Double
    @Binding var timeOffset: Double

    // Callbacks
    let onSyncToggle: () -> Void
    let onEllipseChange: (Int) -> Void
    let onFrameStep: (Bool) -> Void
    let onPreviousEllipse: () -> Void
    let onNextEllipse: () -> Void
    let canGoPreviousEllipse: () -> Bool
    let canGoNextEllipse: () -> Bool

    @State private var isDraggingSlider = false

    var body: some View {
        // Main player controls (Info-Box wurde nach außen verschoben)
        VStack(spacing: 6) {
            // Timeline - dünner
            Slider(
                value: Binding(
                    get: { currentTime },
                    set: { newValue in
                        currentTime = newValue
                        if isDraggingSlider {
                            seekWithSync(to: newValue)
                        }
                    }
                ),
                in: 0...max(duration, 1)
            ) { editing in
                isDraggingSlider = editing
                if !editing {
                    seekWithSync(to: currentTime)
                }
            }
            .tint(LiquidGlassColors.accent)
            .frame(height: 16)

            // Time labels
            HStack {
                Text(formatTime(currentTime))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text(formatTime(duration))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }

            // Fixed control buttons on one line - immer vollständig sichtbar
            HStack(spacing: 15) {
                // Sync button (nur bei Player 2)
                if isPlayer2 {
                    Button(action: onSyncToggle) {
                        Image(systemName: isSynchronized ? "link" : "link.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(isSynchronized ? LiquidGlassColors.accent : .white.opacity(0.7))
                            .frame(width: 36, height: 36)
                    }
                }

                // Ellipse backward - immer sichtbar
                Button(action: onPreviousEllipse) {
                    Image(systemName: "chevron.left.2")
                        .font(.title3)
                        .foregroundColor(canGoPreviousEllipse() ? .white : .white.opacity(0.3))
                        .frame(width: 38, height: 50)
                }
                .disabled(!canGoPreviousEllipse())

                // Frame backward
                Button(action: {
                    onFrameStep(false)
                }) {
                    Image(systemName: "backward.frame")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 50)
                }

                // Play/Pause button
                Button(action: {
                    isPlaying.toggle()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(LiquidGlassColors.primary)
                        )
                        .overlay(
                            Circle()
                                .stroke(LiquidGlassColors.glassBorder, lineWidth: 1.5)
                        )
                        .shadow(color: LiquidGlassColors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                // Frame forward
                Button(action: {
                    onFrameStep(true)
                }) {
                    Image(systemName: "forward.frame")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 50)
                }

                // Ellipse forward - immer sichtbar
                Button(action: onNextEllipse) {
                    Image(systemName: "chevron.right.2")
                        .font(.title3)
                        .foregroundColor(canGoNextEllipse() ? .white : .white.opacity(0.3))
                        .frame(width: 38, height: 50)
                }
                .disabled(!canGoNextEllipse())

                // Trajectory toggle (ganz rechts)
                Button(action: {
                    showTrajectory.toggle()
                }) {
                    Image(systemName: showTrajectory ? "eye" : "eye.slash")
                        .font(.system(size: 16))
                        .foregroundColor(showTrajectory ? LiquidGlassColors.accent : .white.opacity(0.7))
                        .frame(width: 36, height: 36)
                }
            }
            .frame(height: 50)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.white.opacity(0.12), radius: 10, x: 0, y: 5)
        )
    }

    private func seekWithSync(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1000)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)

        // When synchronized, maintain the time offset
        if isSynchronized, let syncPlayer = otherPlayer {
            let syncTime: Double
            if isPlayer2 {
                // Player 2: otherTime = currentTime - offset
                syncTime = time - timeOffset
            } else {
                // Player 1: otherTime = currentTime + offset
                syncTime = time + timeOffset
            }
            let clampedSyncTime = max(0, min(syncTime, otherDuration))
            syncPlayer.seek(to: CMTime(seconds: clampedSyncTime, preferredTimescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero)
            otherCurrentTime = clampedSyncTime
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        let milliseconds = Int((seconds - Double(totalSeconds)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, milliseconds)
    }
}

// MARK: - Dual Speed Control
struct DualSpeedControl: View {
    @Binding var speed1: Float
    @Binding var speed2: Float
    @Binding var hasTriggeredSwipe1: Bool
    @Binding var hasTriggeredSwipe2: Bool
    let isPlaying: Bool
    let player1: AVPlayer?
    let player2: AVPlayer?

    // Haptisches Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    // Speed arrays für beide Richtungen
    private let speedsUp: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0]
    private let speedsDown: [Float] = [1.0, 0.8, 0.7, 0.6, 0.5]

    // Alle Geschwindigkeiten kombiniert und sortiert
    private var allSpeeds: [Float] {
        Array(Set(speedsUp + speedsDown)).sorted()
    }

    var body: some View {
        HStack(spacing: 6) {
            // Video 1 Speed Control - Kompakt wie Back Button
            speedButton(
                speed: speed1,
                hasTriggeredSwipe: $hasTriggeredSwipe1,
                player: player1,
                arrowIcon: "arrow.up",
                onSpeedChange: { newSpeed in
                    speed1 = newSpeed
                }
            )

            // Vertikaler Divider
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1, height: 18)

            // Video 2 Speed Control - Kompakt wie Back Button
            speedButton(
                speed: speed2,
                hasTriggeredSwipe: $hasTriggeredSwipe2,
                player: player2,
                arrowIcon: "arrow.down",
                onSpeedChange: { newSpeed in
                    speed2 = newSpeed
                }
            )
        }
        .frame(height: 18)
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 100)
        .interactiveLiquidGlass(cornerRadius: 12)
    }

    @ViewBuilder
    private func speedButton(
        speed: Float,
        hasTriggeredSwipe: Binding<Bool>,
        player: AVPlayer?,
        arrowIcon: String,
        onSpeedChange: @escaping (Float) -> Void
    ) -> some View {
        // Kompakter Button wie Back Button - feste Breite basierend auf Inhalt
        HStack(spacing: 3) {
            Image(systemName: arrowIcon)
                .font(.system(size: 9, weight: .semibold))

            Text("\(formatSpeed(speed))x")
                .font(.system(size: 9))
        }
        .contentShape(Rectangle())
        .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let verticalMovement = value.translation.height

                            // Nach oben: 3px Schwelle, nach unten: 1.5px Schwelle
                            let threshold: CGFloat = verticalMovement < 0 ? 3 : 1.5

                            if abs(verticalMovement) >= threshold && !hasTriggeredSwipe.wrappedValue {
                                hasTriggeredSwipe.wrappedValue = true
                                impactFeedback.prepare()

                                let direction = verticalMovement < 0 ? 1 : -1  // 1 = up (schneller), -1 = down (langsamer)

                                // Einmaliger Swipe: eine Stufe
                                let newSpeed = changeSpeedOneStep(currentSpeed: speed, direction: direction)
                                onSpeedChange(newSpeed)

                                // WICHTIG: Nicht player?.rate setzen - das startet das Video!
                                // Das wird von onChange(of: playbackSpeed) gehandelt wenn Video spielt

                                impactFeedback.impactOccurred()

                                let emoji = direction == 1 ? "⏩" : "⏪"
                                print("\(emoji) Speed changed to \(newSpeed)x")
                            }
                        }
                        .onEnded { value in
                            let verticalMovement = value.translation.height

                            // Wenn keine Swipe-Geste getriggert wurde und Bewegung minimal war → Tap
                            if !hasTriggeredSwipe.wrappedValue && abs(verticalMovement) < 3 {
                                // Tap resettet auf 1.0x
                                onSpeedChange(1.0)
                                // WICHTIG: Nicht player?.rate setzen - das startet das Video!
                                // Das wird von onChange(of: playbackSpeed) gehandelt wenn Video spielt
                                impactFeedback.impactOccurred(intensity: 0.7)
                                print("🔄 Tap: Speed reset to 1.0x")
                            }

                            hasTriggeredSwipe.wrappedValue = false
                        }
                )
    }

    private func formatSpeed(_ speed: Float) -> String {
        if speed == 1.0 {
            return "1"
        } else if speed == floor(speed) {
            return String(format: "%.0f", speed)
        } else {
            // Eine Dezimalstelle für saubere Anzeige (0.8, 0.7, etc.)
            let formatted = String(format: "%.1f", speed)
            // Entferne .0 für ganze Zahlen
            return formatted.hasSuffix(".0") ? String(formatted.dropLast(2)) : formatted
        }
    }

    private func changeSpeedOneStep(currentSpeed: Float, direction: Int) -> Float {
        let speeds = allSpeeds

        if direction == 1 {
            // Nach oben = schneller (step-by-step durch alle Geschwindigkeiten)
            if let currentIndex = speeds.firstIndex(of: currentSpeed) {
                let nextIndex = min(currentIndex + 1, speeds.count - 1)
                if nextIndex != currentIndex {
                    return speeds[nextIndex]
                }
            } else {
                // Nicht in speeds, finde nächste höhere Speed
                return speeds.first(where: { $0 > currentSpeed }) ?? speeds.last ?? 1.0
            }
        } else {
            // Nach unten = langsamer (step-by-step durch alle Geschwindigkeiten)
            if let currentIndex = speeds.firstIndex(of: currentSpeed) {
                let nextIndex = max(currentIndex - 1, 0)
                if nextIndex != currentIndex {
                    return speeds[nextIndex]
                }
            } else {
                // Nicht in speeds, finde nächste niedrigere Speed
                return speeds.reversed().first(where: { $0 < currentSpeed }) ?? speeds.first ?? 1.0
            }
        }

        return currentSpeed
    }
}
