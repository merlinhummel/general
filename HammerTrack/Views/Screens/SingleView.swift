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

    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background layer: Video (fullscreen including Dynamic Island area)
            if let player = player {
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
                .ignoresSafeArea(.all, edges: .all)
                .background(Color.black)
            } else {
                // Empty state background
                LiquidGlassBackground()
                    .ignoresSafeArea(.all, edges: .all)
            }

            // Overlay layer: UI elements
            VStack(spacing: 0) {
                // Header with individual Liquid Glass buttons
                HStack {
                    // Back button as Liquid Glass
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
                        .liquidGlassEffect(style: .thin, cornerRadius: 12)
                    }

                    Spacer()

                    // Title as Liquid Glass button
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
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .padding(.top, 0) // Allow it to reach top edge

                Spacer()

                // Middle content: Processing overlay and trajectory toggle
                if let player = player {
                    ZStack {
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

                        // Trajectory toggle only (no ellipse info)
                        VStack {
                            Spacer()

                            HStack {
                                Spacer()
                                Button(action: { showTrajectory.toggle() }) {
                                    Image(systemName: showTrajectory ? "eye" : "eye.slash")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .liquidGlassEffect(style: .thin, cornerRadius: 18)
                                }
                                .padding(.trailing, 12)
                                .padding(.bottom, 12)
                            }
                        }
                    }
                } else {
                    // Empty state content
                    VStack(spacing: 20) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))

                        Text("Wählen Sie ein Video aus")
                            .font(.headline)
                            .foregroundColor(.white)

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

                Spacer()

                // Bottom: Video controls with Liquid Glass
                if let player = player {
                    VideoControlsView(
                        player: player,
                        isPlaying: $isPlaying,
                        currentTime: $currentTime,
                        duration: $duration,
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
        .sheet(isPresented: $showingVideoPicker) {
            VideoPicker(selectedVideoURL: $selectedVideoURL)
        }
        .onChange(of: selectedVideoURL) { _, newURL in
            if let url = newURL {
                setupPlayer(with: url)
                processVideo(url: url)
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
            } catch {
                print("Error loading duration: \(error)")
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
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                    if let url = url {
                        // Copy to temporary location
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.copyItem(at: url, to: tempURL)
                        
                        DispatchQueue.main.async {
                            self.parent.selectedVideoURL = tempURL
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
    
    var body: some View {
        ZStack(alignment: .top) {
            // Main player controls
            VStack(spacing: 8) {
                // Timeline
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
                .frame(height: 20)

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

                // Fixed control buttons on one line
                HStack(spacing: 15) {
                    // Ellipse backward button (ganz links)
                    Button(action: {
                        previousEllipse()
                    }) {
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
                    .onLongPressGesture(minimumDuration: 0.2, maximumDistance: .infinity, pressing: { pressing in
                        if pressing {
                            startFrameStepping(forward: false)
                        } else {
                            stopFrameStepping()
                        }
                    }, perform: {})

                    // Play/Pause button - fixed position
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
                    .onLongPressGesture(minimumDuration: 0.2, maximumDistance: .infinity, pressing: { pressing in
                        if pressing {
                            startFrameStepping(forward: true)
                        } else {
                            stopFrameStepping()
                        }
                    }, perform: {})

                    // Ellipse forward button (ganz rechts)
                    Button(action: {
                        nextEllipse()
                    }) {
                        Image(systemName: "chevron.right.2")
                            .font(.title3)
                            .foregroundColor(canGoNextEllipse() ? .white : .white.opacity(0.3))
                            .frame(width: 38, height: 50)
                    }
                    .disabled(!canGoNextEllipse())
                }
                .frame(height: 50) // Fixed height for button row
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .liquidGlassEffect(style: .thin, cornerRadius: 16)

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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liquidGlassEffect(style: .thin, cornerRadius: 10)
                .offset(y: -45) // Float above the controls
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liquidGlassEffect(style: .thin, cornerRadius: 10)
                .offset(y: -45) // Float above the controls
            } else if totalEllipses > 0 {
                Text("Zwischen Ellipsen")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlassEffect(style: .thin, cornerRadius: 10)
                    .offset(y: -45)
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
