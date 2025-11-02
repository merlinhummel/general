import SwiftUI
import PhotosUI
import AVKit
import UniformTypeIdentifiers

struct SingleView: View {
    @State private var showingVideoPicker = false
    @State private var selectedVideoURL: URL?
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserver: Any?
    
    @StateObject private var hammerTracker = HammerTracker()
    @State private var showTrajectory = true
    @State private var showTurningPoints = true  // NEU: Toggle für Umkehrpunkte
    @State private var videoSize: CGSize = .zero
    @State private var currentEllipseAngle: Double? = nil
    @State private var currentEllipseIndex: Int? = nil
    @State private var totalEllipses: Int = 0
    @State private var turningPointVisualizations: [TurningPointVisualization] = []  // NEU

    // ELLIPSEN-NAVIGATION
    @State private var selectedEllipseIndex: Int? = nil  // Welche Ellipse ist ausgewählt (0-basiert)
    @State private var ellipseViewMode: Bool = false  // Nur ausgewählte Ellipse anzeigen?

    // PLAYBACK SPEED (Persistent Storage)
    @AppStorage("playbackSpeed") private var playbackSpeedStorage: Double = 1.0
    @State private var hasTriggeredSwipe = false

    // Loading Animation
    @State private var isLoadingVideo = false
    @State private var rotationAngle: Double = 0

    // Helper for Float conversion
    private var playbackSpeed: Float {
        get { Float(playbackSpeedStorage) }
        nonmutating set { playbackSpeedStorage = Double(newValue) }
    }

    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Video layer - Apple Gallery style (full width, vertically centered)
            if let player = player {
                GeometryReader { geometry in
                    ZoomableVideoView(
                        player: player,
                        trajectory: showTrajectory ? hammerTracker.currentTrajectory : nil,
                        currentTime: $currentTime,
                        showFullTrajectory: false,
                        showTrajectory: showTrajectory,
                        selectedEllipseIndex: ellipseViewMode ? (isPlaying ? currentEllipseIndex.map { $0 - 1 } : selectedEllipseIndex) : nil,
                        analysisResult: hammerTracker.analysisResult,
                        onEllipseTapped: { tappedIndex in
                            if let index = tappedIndex {
                                // Ellipse getippt → Aktiviere Ellipsen-Modus
                                selectedEllipseIndex = index
                                ellipseViewMode = true
                                // Springe zur getippten Ellipse
                                seekToEllipse(index: index)
                            } else {
                                // Außerhalb getippt → Deaktiviere Ellipsen-Modus
                                ellipseViewMode = false
                                selectedEllipseIndex = nil
                            }
                        }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .ignoresSafeArea()
            } else {
                // Empty state background
                LiquidGlassBackground()
                    .ignoresSafeArea()
            }

            // Empty state content - absolut zentriert in Bildschirmmitte (wie Compare View)
            if player == nil {
                VStack(spacing: 20) {
                    // Rotierendes Zahnrad beim Laden, sonst normales Icon
                    ZStack {
                        if isLoadingVideo {
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
                            Image(systemName: "video.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    Text(isLoadingVideo ? "Video wird verarbeitet..." : "Wählen Sie ein Video aus")
                        .font(.headline)
                        .foregroundColor(.white)

                    if !isLoadingVideo {
                        Button(action: {
                            showingVideoPicker = true
                        }) {
                            Text("Video auswählen")
                                .foregroundColor(.white)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 15)
                                .interactiveLiquidGlass(cornerRadius: 15)
                        }
                    }
                }
                .onChange(of: isLoadingVideo) { _, loading in
                    if loading {
                        rotationAngle = 0  // Reset rotation
                    }
                }
            }

            // Overlay layer: UI elements
            VStack(spacing: 0) {
                // Header with iOS 26 Glass buttons
                HStack {
                    // Back button - iOS 26 Interactive Glass
                    Button(action: {
                        if player != nil {
                            // Reset player and go back to selection
                            player = nil
                            selectedVideoURL = nil
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
                    }
                    .interactiveLiquidGlass(cornerRadius: 12)

                    Spacer()

                    // Title with iOS 26 Glass
                    Text("Single View")
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
                .padding(.horizontal, 20)  // Gleicher Abstand wie Player unten
                .padding(.vertical, 12)
                .padding(.top, 0) // Allow it to reach top edge

                Spacer()

                // Middle content: Processing overlay only (wenn Video geladen)
                if let player = player {
                    // Processing overlay with Liquid Glass
                    if hammerTracker.isProcessing {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Analysiere Video...")
                                .font(.headline)
                                .foregroundColor(.white)

                            ProgressView(value: hammerTracker.progress)
                                .frame(width: 200)
                                .tint(LiquidGlassColors.accent)

                            Text("\(Int(hammerTracker.progress * 100))%")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .floatingGlassCard(cornerRadius: 20)
                    }
                }

                Spacer()

                // Bottom: Video controls with Liquid Glass
                if let player = player {
                    VideoControlsView(
                        player: player,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: $duration,
                        playbackSpeed: Binding(
                            get: { Float(playbackSpeedStorage) },
                            set: { playbackSpeedStorage = Double($0) }
                        ),
                        hasTriggeredSwipe: $hasTriggeredSwipe,
                        showTrajectory: $showTrajectory,
                        currentEllipseAngle: currentEllipseAngle,
                        currentEllipseIndex: currentEllipseIndex,
                        totalEllipses: totalEllipses,
                        selectedEllipseIndex: $selectedEllipseIndex,
                        ellipseViewMode: $ellipseViewMode,
                        analysisResult: hammerTracker.analysisResult,
                        onEllipseChange: { seekToEllipse(index: $0) }
                    )
                    .frame(maxWidth: 500) // 15% schmaler durch max width
                    .padding(.horizontal, 20) // Gleicher Abstand wie zu den Seiten
                    .padding(.bottom, 20) // Gleicher Abstand zum unteren Rand
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)  // VStack nimmt volle Höhe ein, Elemente oben ausgerichtet
            .ignoresSafeArea(edges: .bottom)  // Ignoriere Safe Area unten, damit 20px wirklich zum physischen Bildschirmrand sind
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingVideoPicker, onDismiss: {
            // Wenn Video ausgewählt wurde, starte Loading-Animation
            if selectedVideoURL != nil {
                isLoadingVideo = true
            }
        }) {
            VideoPicker(selectedVideoURL: $selectedVideoURL, isLoadingVideo: $isLoadingVideo)
        }
        .onChange(of: selectedVideoURL) { _, newURL in
            if let url = newURL {
                setupPlayer(with: url)
                processVideo(url: url)
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                player?.rate = playbackSpeed
                player?.play()
            } else {
                player?.pause()
            }
        }
        .onChange(of: playbackSpeed) { _, newSpeed in
            if isPlaying {
                player?.rate = newSpeed
            }
        }
        .onDisappear {
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
        }
    }
    
    private func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)

        // Get video duration and size
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                self.duration = duration.seconds

                if let track = asset.tracks(withMediaType: .video).first {
                    let size = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    let transformedSize = size.applying(transform)
                    // Use absolute values to ensure positive dimensions
                    self.videoSize = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
                }

                // Loading fertig - Animation ausblenden
                await MainActor.run {
                    self.isLoadingVideo = false
                }
            } catch {
                print("Error loading duration: \(error)")
                await MainActor.run {
                    self.isLoadingVideo = false
                }
            }
        }
        
        // Add time observer
        if let player = player {
            let interval = CMTime(seconds: 0.01, preferredTimescale: 600)
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
                currentTime = time.seconds
                updateCurrentEllipseAngle()
            }
        }
    }
    
    private func processVideo(url: URL) {
        hammerTracker.processVideo(url: url) { result in
            switch result {
            case .success(let trajectory):
                print("Video processing complete. Detected \(trajectory.frames.count) frames")
                if let analysis = hammerTracker.analyzeTrajectory() {
                    print("Analysis complete: \(analysis.ellipses.count) ellipses found")
                }
            case .failure(let error):
                print("Error processing video: \(error)")
            }
        }
    }
    
    private func updateCurrentEllipseAngle() {
        guard let analysis = hammerTracker.analysisResult else {
            currentEllipseAngle = nil
            currentEllipseIndex = nil
            totalEllipses = 0
            return
        }

        totalEllipses = analysis.ellipses.count

        // Find the current ellipse based on current time
        for (index, ellipse) in analysis.ellipses.enumerated() {
            if let startTime = ellipse.frames.first?.timestamp,
               let endTime = ellipse.frames.last?.timestamp,
               currentTime >= startTime && currentTime <= endTime {
                currentEllipseAngle = ellipse.angle
                currentEllipseIndex = index + 1 // 1-based indexing for display
                return
            }
        }

        currentEllipseAngle = nil
        currentEllipseIndex = nil
    }

    // MARK: - Ellipsen-Navigation
    private func seekToEllipse(index: Int) {
        guard let analysis = hammerTracker.analysisResult,
              index >= 0 && index < analysis.ellipses.count,
              let player = player else { return }

        let ellipse = analysis.ellipses[index]

        // Springe zum Start der Ellipse
        if let startTime = ellipse.frames.first?.timestamp {
            let cmTime = CMTime(seconds: startTime, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            currentTime = startTime

            // Pause das Video wenn wir zur Ellipse springen
            if isPlaying {
                player.pause()
                isPlaying = false
            }
        }
    }
}

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Binding var isLoadingVideo: Bool
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Wenn Video ausgewählt wurde, aktiviere Loading sofort
            if !results.isEmpty {
                parent.isLoadingVideo = true
            }

            parent.presentationMode.wrappedValue.dismiss()

            guard let provider = results.first?.itemProvider else { return }

            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let url = url {
                        // Copy to temporary location
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        do {
                            // Falls Datei existiert, erst löschen
                            try? FileManager.default.removeItem(at: tempURL)
                            // Kopieren
                            try FileManager.default.copyItem(at: url, to: tempURL)

                            DispatchQueue.main.async {
                                self.parent.selectedVideoURL = tempURL
                            }
                        } catch {
                            print("❌ Error copying video file: \(error)")
                            DispatchQueue.main.async {
                                self.parent.isLoadingVideo = false
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.parent.isLoadingVideo = false
                        }
                    }
                }
            }
        }
    }
}

struct VideoControlsView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var playbackSpeed: Float
    @Binding var hasTriggeredSwipe: Bool
    @Binding var showTrajectory: Bool
    let currentEllipseAngle: Double?
    let currentEllipseIndex: Int?
    let totalEllipses: Int

    // Ellipsen-Navigation
    @Binding var selectedEllipseIndex: Int?
    @Binding var ellipseViewMode: Bool
    let analysisResult: TrajectoryAnalysis?
    let onEllipseChange: (Int) -> Void

    @State private var isDraggingSlider = false
    @State private var frameStepTimer: Timer?
    @State private var frameStepCount = 0

    // Haptisches Feedback
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    // Speed arrays
    private let speedsUp: [Float] = [1.0, 1.25, 1.5, 1.75, 2.0]
    private let speedsDown: [Float] = [1.0, 0.8, 0.7, 0.6, 0.5]
    private var allSpeeds: [Float] {
        Array(Set(speedsUp + speedsDown)).sorted()
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Main player controls
            VStack(spacing: 6) {
                // Timeline - dünner
                Slider(
                    value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            currentTime = newValue
                            if isDraggingSlider {
                                seek(to: newValue)
                            }
                        }
                    ),
                    in: 0...max(duration, 1)
                ) { editing in
                    isDraggingSlider = editing
                    if !editing {
                        seek(to: currentTime)
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

                // Control buttons - Simple Compare View Style
                HStack(spacing: 15) {
                    // Speed Control (links)
                    speedButton()

                    // Ellipse backward
                    Button(action: previousEllipse) {
                        Image(systemName: "chevron.left.2")
                            .font(.title3)
                            .foregroundColor(canGoPreviousEllipse() ? .white : .white.opacity(0.3))
                            .frame(width: 38, height: 50)
                    }
                    .disabled(!canGoPreviousEllipse())

                    // Frame backward
                    Button(action: {
                        stepFrame(forward: false)
                    }) {
                        Image(systemName: "backward.frame")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 50)
                    }

                    // Play/Pause button
                    Button(action: togglePlayPause) {
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
                        stepFrame(forward: true)
                    }) {
                        Image(systemName: "forward.frame")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 50)
                    }

                    // Ellipse forward
                    Button(action: nextEllipse) {
                        Image(systemName: "chevron.right.2")
                            .font(.title3)
                            .foregroundColor(canGoNextEllipse() ? .white : .white.opacity(0.3))
                            .frame(width: 38, height: 50)
                    }
                    .disabled(!canGoNextEllipse())

                    // Trajectory toggle (rechts)
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

            // Ellipse info overlay - floats above controls without shifting them
            if ellipseViewMode,
               let selectedIndex = selectedEllipseIndex,
               let analysis = analysisResult,
               selectedIndex < analysis.ellipses.count {
                // Ellipsen-Modus: Zeige ausgewählte Ellipse
                let ellipse = analysis.ellipses[selectedIndex]
                VStack(spacing: 2) {
                    Text("Ellipse \(selectedIndex + 1)/\(totalEllipses)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 4) {
                        Image(systemName: ellipse.angle > 0 ? "arrow.up.right" : "arrow.up.left")
                            .font(.caption2)
                            .foregroundColor(ellipse.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)

                        Text(String(format: "%.1f°", abs(ellipse.angle)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text(ellipse.angle > 0 ? "rechts" : "links")
                            .font(.caption2)
                            .foregroundColor(ellipse.angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: LiquidGlassColors.accent.opacity(0.2), radius: 12, x: 0, y: 4)
                )
                .offset(y: -50)
            } else if let angle = currentEllipseAngle,
                      let index = currentEllipseIndex,
                      totalEllipses > 0 {
                // Normal-Modus: Zeige aktuelle Ellipse während des Abspielens
                VStack(spacing: 2) {
                    Text("Ellipse \(index)/\(totalEllipses)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 4) {
                        Image(systemName: angle > 0 ? "arrow.up.right" : "arrow.up.left")
                            .font(.caption2)
                            .foregroundColor(angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)

                        Text(String(format: "%.1f°", abs(angle)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text(angle > 0 ? "rechts" : "links")
                            .font(.caption2)
                            .foregroundColor(angle > 0 ? LiquidGlassColors.accent : LiquidGlassColors.primary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: LiquidGlassColors.accent.opacity(0.2), radius: 12, x: 0, y: 4)
                )
                .offset(y: -50)
            } else if totalEllipses > 0 {
                Text("Zwischen Ellipsen")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0.15)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: LiquidGlassColors.accent.opacity(0.2), radius: 12, x: 0, y: 4)
                    )
                    .offset(y: -50)
            }
        }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem,
                    queue: .main
                ) { _ in
                    isPlaying = false
                    seek(to: 0)
                }
            }
        }
    }

    // MARK: - Speed Control Button (iOS 26 Interactive Glass)
    @ViewBuilder
    private func speedButton() -> some View {
        SpeedControlButton(
            playbackSpeed: $playbackSpeed,
            hasTriggeredSwipe: $hasTriggeredSwipe,
            isPlaying: isPlaying,
            player: player,
            formatSpeed: formatSpeed,
            changeSpeedOneStep: changeSpeedOneStep,
            allSpeeds: allSpeeds
        )
    }
}

// MARK: - Speed Control Button Component (Simple Compare View Style)
struct SpeedControlButton: View {
    @Binding var playbackSpeed: Float
    @Binding var hasTriggeredSwipe: Bool
    let isPlaying: Bool
    let player: AVPlayer
    let formatSpeed: (Float) -> String
    let changeSpeedOneStep: (Float, Int) -> Float
    let allSpeeds: [Float]

    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Text("\(formatSpeed(playbackSpeed))x")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let verticalMovement = value.translation.height
                        let threshold: CGFloat = verticalMovement < 0 ? 3 : 1.5

                        if abs(verticalMovement) >= threshold && !hasTriggeredSwipe {
                            hasTriggeredSwipe = true
                            impactFeedback.prepare()

                            let direction = verticalMovement < 0 ? 1 : -1
                            let newSpeed = changeSpeedOneStep(playbackSpeed, direction)
                            playbackSpeed = newSpeed

                            if isPlaying {
                                player.rate = newSpeed
                            }

                            impactFeedback.impactOccurred()
                        }
                    }
                    .onEnded { value in
                        let verticalMovement = value.translation.height

                        if !hasTriggeredSwipe && abs(verticalMovement) < 3 {
                            // Tap resets to 1.0x
                            playbackSpeed = 1.0
                            if isPlaying {
                                player.rate = 1.0
                            }
                            impactFeedback.impactOccurred(intensity: 0.7)
                        }

                        hasTriggeredSwipe = false
                    }
            )
    }
}

// MARK: - VideoControlsView Extension
extension VideoControlsView {

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

    private func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    private func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }
    
    private func stepFrame(forward: Bool) {
        let frameRate: Double = 30 // Assuming 30 fps
        let frameDuration = 1.0 / frameRate
        let currentCMTime = player.currentTime()
        let currentSeconds = currentCMTime.seconds
        
        let newTime = forward ? currentSeconds + frameDuration : currentSeconds - frameDuration
        let clampedTime = max(0, min(newTime, duration))
        
        seek(to: clampedTime)
    }
    
    private func startFrameStepping(forward: Bool) {
        frameStepCount = 0
        
        // 7 frames per second when holding
        frameStepTimer = Timer.scheduledTimer(withTimeInterval: 1.0/7.0, repeats: true) { _ in
            stepFrame(forward: forward)
        }
    }
    
    private func stopFrameStepping() {
        frameStepTimer?.invalidate()
        frameStepTimer = nil
        frameStepCount = 0
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        let milliseconds = Int((seconds - Double(totalSeconds)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, secs, milliseconds)
    }

    // MARK: - Ellipsen-Navigation Funktionen
    private func previousEllipse() {
        guard let analysis = analysisResult,
              !analysis.ellipses.isEmpty else { return }

        // Aktiviere Ellipsen-Ansicht beim ersten Klick
        if !ellipseViewMode {
            // Finde aktuelle Ellipse basierend auf currentTime
            if let currentIndex = findCurrentEllipseIndex() {
                selectedEllipseIndex = currentIndex
            } else {
                selectedEllipseIndex = 0
            }
            ellipseViewMode = true
            onEllipseChange(selectedEllipseIndex!)
            return
        }

        // Gehe zur vorherigen Ellipse
        if let current = selectedEllipseIndex, current > 0 {
            selectedEllipseIndex = current - 1
            onEllipseChange(selectedEllipseIndex!)
        }
    }

    private func nextEllipse() {
        guard let analysis = analysisResult,
              !analysis.ellipses.isEmpty else { return }

        // Aktiviere Ellipsen-Ansicht beim ersten Klick
        if !ellipseViewMode {
            // Finde aktuelle Ellipse basierend auf currentTime
            if let currentIndex = findCurrentEllipseIndex() {
                selectedEllipseIndex = currentIndex
            } else {
                selectedEllipseIndex = 0
            }
            ellipseViewMode = true
            onEllipseChange(selectedEllipseIndex!)
            return
        }

        // Gehe zur nächsten Ellipse
        if let current = selectedEllipseIndex, current < analysis.ellipses.count - 1 {
            selectedEllipseIndex = current + 1
            onEllipseChange(selectedEllipseIndex!)
        }
    }

    private func canGoPreviousEllipse() -> Bool {
        guard let analysis = analysisResult,
              !analysis.ellipses.isEmpty else { return false }

        if !ellipseViewMode {
            return true  // Erster Klick ist immer möglich
        }

        return selectedEllipseIndex ?? 0 > 0
    }

    private func canGoNextEllipse() -> Bool {
        guard let analysis = analysisResult,
              !analysis.ellipses.isEmpty else { return false }

        if !ellipseViewMode {
            return true  // Erster Klick ist immer möglich
        }

        return (selectedEllipseIndex ?? 0) < analysis.ellipses.count - 1
    }

    private func findCurrentEllipseIndex() -> Int? {
        guard let analysis = analysisResult else { return nil }

        // Finde Ellipse basierend auf currentTime
        for (index, ellipse) in analysis.ellipses.enumerated() {
            if let startTime = ellipse.frames.first?.timestamp,
               let endTime = ellipse.frames.last?.timestamp,
               currentTime >= startTime && currentTime <= endTime {
                return index
            }
        }

        // Wenn keine Ellipse gefunden, nimm die erste
        return 0
    }
}
